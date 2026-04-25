class PwlRecalculationJob < ApplicationJob
  queue_as :lab_extraction

  # For each parameter: which spec the values come from, the JSONB key holding the
  # per-sublot value, and the keys holding the parsed L/U limits. Add new entries
  # here to extend PWL coverage (mat_density via P-403 etc.).
  PARAMETERS = {
    "air_voids" => {
      spec_code: "P-401",
      value_key: "air_voids_avg",
      lower_limit_key: "air_voids_min_pct",
      upper_limit_key: "air_voids_max_pct"
    }
  }.freeze

  def perform(asphalt_lot_id)
    lot = AsphaltLot.find_by(id: asphalt_lot_id)
    return unless lot

    PARAMETERS.each do |parameter, source|
      results = lot.lab_test_results.where(spec_code: source[:spec_code]).order(:sublot_number, :id)
      values = results.map { |r| r.data&.dig(source[:value_key]) }.compact

      lower_limit = first_non_nil(results, source[:lower_limit_key])
      upper_limit = first_non_nil(results, source[:upper_limit_key])

      calc_result = PwlCalculator.new(values, lower_limit: lower_limit, upper_limit: upper_limit).call
      PwlCalculation.upsert_from_result(lot, parameter, calc_result, sample_values: values)
    end
  end

  private

  def first_non_nil(results, key)
    results.each do |r|
      v = r.data&.dig(key)
      return v unless v.nil?
    end
    nil
  end
end
