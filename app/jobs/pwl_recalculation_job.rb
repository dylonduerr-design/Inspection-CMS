class PwlRecalculationJob < ApplicationJob
  queue_as :lab_extraction

  # P-401 acceptance is statistical PWL (FAA AC 150/5370-10H) for every
  # parameter. Limits are project-level settings; PDF-stated limits remain in
  # raw result data only for audit. Mat vs joint is selected by JSONB containment
  # on `core_type`.
  P401_PARAMETERS = {
    "air_voids" => {
      spec_code: "P-401",
      result_kind: LabTestResult::RESULT_KIND_HMA_AIR_VOIDS,
      value_key: "air_voids_avg",
      project_limit_parameter: "air_voids",
      required_limits: :both,
      data_filter: nil
    },
    "mat_density" => {
      spec_code: "P-401",
      result_kind: LabTestResult::RESULT_KIND_CORE_COMPACTION,
      value_key: "compaction_pct",
      project_limit_parameter: "mat_density",
      required_limits: :lower,
      data_filter: { "core_type" => "mat" }
    },
    "joint_density" => {
      spec_code: "P-401",
      result_kind: LabTestResult::RESULT_KIND_CORE_COMPACTION,
      value_key: "compaction_pct",
      project_limit_parameter: "joint_density",
      required_limits: :lower,
      data_filter: { "core_type" => "joint" }
    }
  }.freeze

  # P-403 uses simple lot-average vs. fixed FAA item P-403 thresholds.
  # No statistical PWL — we just take the mean of the per-sublot values and
  # check pass/fail. Limits hardcoded to the spec defaults.
  P403_PARAMETERS = {
    "mat_density" => {
      spec_code: "P-403",
      result_kind: LabTestResult::RESULT_KIND_CORE_COMPACTION,
      value_key: "compaction_pct",
      data_filter: { "core_type" => "mat" },
      lower_limit: 94.0,
      upper_limit: nil
    },
    "joint_density" => {
      spec_code: "P-403",
      result_kind: LabTestResult::RESULT_KIND_CORE_COMPACTION,
      value_key: "compaction_pct",
      data_filter: { "core_type" => "joint" },
      lower_limit: 92.0,
      upper_limit: nil
    },
    "air_voids" => {
      # P-403 air voids may be reported on either spec_code, so we don't filter.
      spec_code: nil,
      result_kind: LabTestResult::RESULT_KIND_HMA_AIR_VOIDS,
      value_key: "air_voids_avg",
      data_filter: nil,
      lower_limit: 2.0,
      upper_limit: 5.0
    }
  }.freeze

  def perform(asphalt_lot_id)
    lot = AsphaltLot.find_by(id: asphalt_lot_id)
    return unless lot

    case lot.mix_type
    when "P-403"
      recalculate_p403(lot)
    else
      # Default to P-401 behavior for P-401 and any unrecognized mix_type
      # (preserves prior behavior — calculations only fire when matching data exists).
      recalculate_p401(lot)
    end
  end

  private

  def recalculate_p401(lot)
    P401_PARAMETERS.each do |parameter, source|
      results = source_results(lot, source)
      values = results.map { |r| r.data&.dig(source[:value_key]) }.compact.map(&:to_f)

      if values.empty?
        PwlCalculation.where(asphalt_lot_id: lot.id, parameter: parameter).delete_all
        next
      end

      lower_limit, upper_limit = project_limits_for(lot, source[:project_limit_parameter])

      calc_result =
        if missing_required_limits?(source[:required_limits], lower_limit, upper_limit)
          PwlCalculator::Result.new(
            status: PwlCalculator::STATUS_MISSING_LIMITS,
            n: values.size,
            lower_limit: lower_limit,
            upper_limit: upper_limit
          )
        else
          PwlCalculator.new(values, lower_limit: lower_limit, upper_limit: upper_limit).call
        end
      PwlCalculation.upsert_from_result(lot, parameter, calc_result, sample_values: values)
    end
  end

  def recalculate_p403(lot)
    P403_PARAMETERS.each do |parameter, source|
      results = source_results(lot, source)
      values = results.map { |r| r.data&.dig(source[:value_key]) }.compact.map(&:to_f)

      if values.empty?
        PwlCalculation.where(asphalt_lot_id: lot.id, parameter: parameter).delete_all
        next
      end

      # For compaction parameters, prefer the per-row required_compaction_pct
      # from the lab report — projects may set thresholds tighter or looser
      # than the FAA spec defaults.
      lower_limit =
        if source[:value_key] == "compaction_pct"
          first_non_nil(results, "required_compaction_pct") || source[:lower_limit]
        else
          source[:lower_limit]
        end

      PwlCalculation.upsert_average_threshold(
        lot,
        parameter,
        sample_values: values,
        lower_limit: lower_limit,
        upper_limit: source[:upper_limit]
      )
    end
  end

  def source_results(lot, source)
    scope = lot.lab_test_results
    scope = scope.where(spec_code: source[:spec_code]) if source[:spec_code]
    scope = scope.where(result_kind: source[:result_kind]) if source[:result_kind]
    if source[:data_filter]
      scope = scope.where("data @> ?::jsonb", source[:data_filter].to_json)
    end
    scope.order(:sublot_number, :id)
  end

  def project_limits_for(lot, parameter)
    limit = lot.project.project_lab_test_limits.find_by(spec_code: "P-401", parameter: parameter)
    [limit&.lower_limit&.to_f, limit&.upper_limit&.to_f]
  end

  def missing_required_limits?(required_limits, lower_limit, upper_limit)
    case required_limits
    when :both
      lower_limit.nil? || upper_limit.nil?
    when :lower
      lower_limit.nil?
    when :upper
      upper_limit.nil?
    else
      lower_limit.nil? && upper_limit.nil?
    end
  end

  def first_non_nil(results, key)
    results.each do |r|
      v = r.data&.dig(key)
      return v unless v.nil?
    end
    nil
  end
end
