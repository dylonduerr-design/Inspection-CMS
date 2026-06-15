require "csv"

class LabTestResultsController < ApplicationController
  before_action :set_project
  before_action :set_result, only: %i[edit update destroy]

  def index
    @spec_code = params[:spec_code].presence
    @result_kind_filter = normalize_result_kind(params[:result_kind])
    @result_filter = params[:result].presence
    @date_from = parse_date(params[:date_from])
    @date_to = parse_date(params[:date_to])
    @lot_filter_enabled = asphalt_lot_filter_supported?(@spec_code)
    lot_scope = available_lots_for(@spec_code)
    @available_lot_options = lot_scope.pluck(:lot_number, :id)
    @lot_filter = normalize_lot_filter(@spec_code, params[:lot], lot_scope)

    @results = filtered_results(
                       spec_code: @spec_code,
                       result_kind: @result_kind_filter,
                       result: @result_filter,
                       lot: @lot_filter,
                       date_from: @date_from,
                       date_to: @date_to
                     )
                       .includes(:asphalt_lot, :report)
                       .order(test_date: :desc, id: :desc)
  end

  def edit
  end

  def update
    if @result.update(result_params)
      enqueue_pwl_recalculation(@result.asphalt_lot_id)
      redirect_to project_lab_test_results_path(@project), notice: "Result updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    lot_id = @result.asphalt_lot_id
    @result.destroy!
    enqueue_pwl_recalculation(lot_id)
    redirect_to project_lab_test_results_path(@project), notice: "Result deleted.", status: :see_other
  end

  def export_csv
    spec = params[:spec_code].presence
    result_kind = csv_result_kind_for(spec, params[:result_kind])
    unless %w[P-401 P-403].include?(spec)
      return render plain: "CSV export is available for P-401 and P-403. Use the Excel export for P-610.", status: :unprocessable_entity
    end
    unless csv_supported?(spec, result_kind)
      return render plain: "Choose Mix Properties or Compaction Cores before exporting CSV.", status: :unprocessable_entity
    end

    lot_scope = available_lots_for(spec)
    lot_filter = normalize_lot_filter(spec, params[:lot], lot_scope)
    result_filter = params[:result].presence
    date_from = parse_date(params[:date_from])
    date_to = parse_date(params[:date_to])

    results = filtered_results(
                      spec_code: spec,
                      result_kind: result_kind,
                      result: result_filter,
                      lot: lot_filter,
                      date_from: date_from,
                      date_to: date_to
                    )
                      .includes(:asphalt_lot, :report)
                      .order(test_date: :desc, id: :desc)

    csv_string = CSV.generate do |csv|
      csv << csv_headers_for(result_kind)
      results.each { |r| csv << csv_row_for(result_kind, r) }
    end

    send_data csv_string,
              filename: "lab_test_results_#{spec.downcase}_#{result_kind}_#{Date.current.iso8601}.csv",
              type: "text/csv"
  end

  def export_xlsx
    spec = params[:spec_code].presence
    unless spec == "P-610"
      return render plain: "XLSX export is only available for P-610 results.", status: :unprocessable_entity
    end

    results = @project.lab_test_results
                      .by_spec_code("P-610")
                      .order(test_date: :desc, id: :desc)

    package = P610QaqcXlsxExporter.new(results).build

    send_data package.to_stream.read,
              filename: "p610_qaqc_summary_#{Date.current.iso8601}.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_result
    @result = @project.lab_test_results.find(params[:id])
  end

  def result_params
    params.require(:lab_test_result).permit(:sublot_number, :result, :notes, :test_date, :hes)
  end

  def parse_date(value)
    return nil if value.blank?
    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def filtered_results(spec_code:, result_kind: nil, result: nil, lot: nil, date_from: nil, date_to: nil)
    @project.lab_test_results
            .by_spec_code(spec_code)
            .by_result_kind(result_kind)
            .by_result(result)
            .by_asphalt_lot(lot)
            .by_date_range(date_from, date_to)
  end

  def available_lots_for(spec_code)
    return AsphaltLot.none unless asphalt_lot_filter_supported?(spec_code)

    @project.asphalt_lots.for_mix(spec_code).order(:lot_number, :id)
  end

  def normalize_lot_filter(spec_code, lot_param, scope = available_lots_for(spec_code))
    return nil unless asphalt_lot_filter_supported?(spec_code)

    lot_id = lot_param.presence
    return nil if lot_id.blank?

    scope.where(id: lot_id).pick(:id)
  end

  def asphalt_lot_filter_supported?(spec_code)
    LabTestImport::ASPHALT_SPEC_CODES.include?(spec_code)
  end

  def normalize_result_kind(value)
    kind = value.presence
    return nil unless LabTestResult::RESULT_KINDS.include?(kind)

    kind
  end

  def csv_result_kind_for(spec_code, value)
    kind = normalize_result_kind(value)
    return LabTestResult::RESULT_KIND_CORE_COMPACTION if spec_code == "P-403" && kind.blank?

    kind
  end

  def csv_supported?(spec_code, result_kind)
    case spec_code
    when "P-401"
      [LabTestResult::RESULT_KIND_HMA_AIR_VOIDS, LabTestResult::RESULT_KIND_CORE_COMPACTION].include?(result_kind)
    when "P-403"
      result_kind == LabTestResult::RESULT_KIND_CORE_COMPACTION
    else
      false
    end
  end

  def csv_headers_for(result_kind)
    case result_kind
    when LabTestResult::RESULT_KIND_HMA_AIR_VOIDS
      ["Report Date", "Test Date", "Lot", "Sublot", "Tonnage Pt (T)", "Time in Oven (hrs)",
       "Gyrations", "Gmb Avg", "Gmm Avg", "Air Voids Avg (%)",
       "Air Voids Min (%)", "Air Voids Max (%)", "Result"]
    when LabTestResult::RESULT_KIND_CORE_COMPACTION
      ["Report Date", "Test Date", "Lot", "Sublot", "Core ID", "Core Type", "Thickness AR (in)",
       "Thickness Trimmed (in)", "Gmb", "Gmm", "Compaction (%)",
       "Required (%)", "ASTM", "Result"]
    end
  end

  def csv_row_for(result_kind, result)
    d = result.data || {}
    lot_label = result.asphalt_lot&.lot_number
    case result_kind
    when LabTestResult::RESULT_KIND_HMA_AIR_VOIDS
      [result.report_date, result.test_date, lot_label, result.sublot_number,
       d["tonnage_point_tons"], d["time_in_oven_hrs"], d["gyrations"],
       d["gmb_avg"], d["gmm_avg"], d["air_voids_avg"],
       d["air_voids_min_pct"], d["air_voids_max_pct"], result.result]
    when LabTestResult::RESULT_KIND_CORE_COMPACTION
      [result.report_date, result.test_date, lot_label, result.sublot_number, d["core_id"], d["core_type"],
       d["thickness_as_received_in"], d["thickness_trimmed_in"],
       d["gmb"], d["gmm"], d["compaction_pct"],
       d["required_compaction_pct"], d["astm_standard"], result.result]
    end
  end

  def enqueue_pwl_recalculation(lot_id)
    PwlRecalculationJob.perform_later(lot_id) if lot_id.present?
  end
end
