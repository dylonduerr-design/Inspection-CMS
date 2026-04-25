class PwlCalculation < ApplicationRecord
  belongs_to :asphalt_lot

  validates :parameter, presence: true, uniqueness: { scope: :asphalt_lot_id }
  validates :status, presence: true

  def self.upsert_from_result(asphalt_lot, parameter, result, sample_values:)
    record = find_or_initialize_by(asphalt_lot_id: asphalt_lot.id, parameter: parameter)
    record.assign_attributes(
      n: result.n,
      sample_values: sample_values,
      mean: result.mean,
      std_dev: result.std_dev,
      lower_limit: result.lower_limit,
      upper_limit: result.upper_limit,
      q_lower: result.q_lower,
      q_upper: result.q_upper,
      p_lower: result.p_lower,
      p_upper: result.p_upper,
      pwl_percentage: result.pwl_percentage,
      status: result.status.to_s,
      calculated_at: Time.current
    )
    record.save!
    record
  end
end
