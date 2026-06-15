require "tempfile"

class LabTestExtractionJob < ApplicationJob
  queue_as :lab_extraction

  MAX_RAW_TEXT_BYTES = 200_000

  def perform(lab_test_import_id)
    import = LabTestImport.find_by(id: lab_test_import_id)
    unless import
      Rails.logger.warn("LabTestExtractionJob skipped: import #{lab_test_import_id} no longer exists")
      return
    end

    unless import.source_pdf.attached?
      mark_rejected!(import, ["source_pdf_missing"])
      return
    end

    Tempfile.create(["lab_test_pdf_", ".pdf"], binmode: true) do |tmp|
      import.source_pdf.download { |chunk| tmp.write(chunk) }
      tmp.flush

      payload = PythonPdfExtractor.extract(pdf_path: tmp.path, spec_code: import.spec_code)
      finalize(import, payload)
    end
  rescue PythonPdfExtractor::ExtractionError => e
    Rails.logger.error("LabTestExtractionJob extractor error for import #{lab_test_import_id}: #{e.message}")
    errors = Array(e.payload["errors"]).presence || [e.message]
    mark_rejected!(import, errors) if import&.persisted?
  rescue => e
    Rails.logger.error("LabTestExtractionJob failed for import #{lab_test_import_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    mark_rejected!(import, [e.message]) if import&.persisted?
  end

  private

  def finalize(import, payload)
    rows = Array(payload["rows"])
    errors = Array(payload["errors"])
    header = payload["header"] || {}
    result_kind = payload["result_kind"].presence || LabTestResult.infer_result_kind(import.spec_code, rows.first || {})
    raw_text = payload["raw_text"].to_s[0, MAX_RAW_TEXT_BYTES]

    ActiveRecord::Base.transaction do
      import.update!(
        lab_name: header["lab_name"],
        result_kind: result_kind,
        report_header: header,
        parsed_data: rows,
        extraction_errors: errors,
        row_count: rows.size,
        raw_text: raw_text
      )

      if errors.empty? && rows.any? && result_kind.present? && all_required_fields_present?(result_kind, rows)
        persist_results(import, rows, header, result_kind)
        import.update!(status: "saved")
      else
        import.update!(status: "needs_review")
      end
    end

    import.broadcast_status

    if import.status == "saved"
      affected_lot_ids = import.lab_test_results.distinct.pluck(:asphalt_lot_id).compact
      affected_lot_ids.each { |lot_id| PwlRecalculationJob.perform_later(lot_id) }
    end
  end

  # Multi-lot cores reports emit sublot labels like "L3/SL3" and "L4/SL1" — each
  # row may belong to a different AsphaltLot than the one selected on the upload
  # form. Resolve per-row and fall back to the form selection when the label has
  # no lot prefix (e.g. legacy "TS/SL1" single-lot reports).
  def persist_results(import, rows, header, result_kind)
    lot_resolver = LabTestLotResolver.new(import.project)

    rows.each do |row|
      resolved_lot_id = lot_resolver.resolve(row["sublot_number"]) || import.asphalt_lot_id

      import.lab_test_results.create!(
        project_id:     import.project_id,
        asphalt_lot_id: resolved_lot_id,
        report_id:      import.report_id,
        spec_code:      import.spec_code,
        result_kind:    result_kind,
        lab_name:       header["lab_name"],
        report_date:    parse_date(header["report_date"]),
        test_date:      parse_date(row["test_date"]) || parse_date(header["report_date"]),
        sublot_number:  row["sublot_number"],
        result:         LabTestResult.result_for_import(
                          project: import.project,
                          spec_code: import.spec_code,
                          result_kind: result_kind,
                          data: row,
                          fallback: row["result"]
                        ),
        data:           row
      )
    end
  end

  def all_required_fields_present?(result_kind, rows)
    required = required_fields_for(result_kind)
    rows.all? { |row| required.all? { |f| row[f].present? || row[f] == false } }
  end

  def required_fields_for(result_kind)
    case result_kind
    when LabTestResult::RESULT_KIND_HMA_AIR_VOIDS
      %w[sublot_number test_date gmb_avg gmm_avg air_voids_avg]
    when LabTestResult::RESULT_KIND_CORE_COMPACTION
      %w[sublot_number core_id core_type gmb gmm compaction_pct]
    when LabTestResult::RESULT_KIND_CONCRETE_STRENGTH
      # P-610 may legitimately have nil result/avg_strength when 28-day breaks are still pending,
      # so we don't require those here — only the structural fields that should always be present.
      %w[lab_id_number specified_strength_psi cylinders]
    else
      []
    end
  end

  def parse_date(value)
    return nil if value.blank?
    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def mark_rejected!(import, errors)
    import.update!(status: "rejected", extraction_errors: errors)
    import.broadcast_status
  end
end
