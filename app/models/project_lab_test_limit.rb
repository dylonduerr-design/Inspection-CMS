class ProjectLabTestLimit < ApplicationRecord
  SPEC_CODES = %w[P-401].freeze
  PARAMETERS = %w[air_voids mat_density joint_density].freeze

  DEFINITIONS = [
    {
      spec_code: "P-401",
      parameter: "air_voids",
      label: "P-401 Air Voids",
      lower_label: "Minimum %",
      upper_label: "Maximum %"
    },
    {
      spec_code: "P-401",
      parameter: "mat_density",
      label: "P-401 Mat Density",
      lower_label: "Minimum %",
      upper_label: nil
    },
    {
      spec_code: "P-401",
      parameter: "joint_density",
      label: "P-401 Joint Density",
      lower_label: "Minimum %",
      upper_label: nil
    }
  ].freeze

  belongs_to :project

  validates :spec_code, presence: true, inclusion: { in: SPEC_CODES }
  validates :parameter, presence: true, inclusion: { in: PARAMETERS }
  validates :parameter, uniqueness: { scope: [:project_id, :spec_code] }
  validate :at_least_one_limit

  def self.key_for(spec_code, parameter)
    "#{spec_code}:#{parameter}"
  end

  def self.definition_for(spec_code, parameter)
    DEFINITIONS.find { |definition| definition[:spec_code] == spec_code && definition[:parameter] == parameter }
  end

  def self.label_for(spec_code, parameter)
    definition_for(spec_code, parameter)&.fetch(:label) || parameter.to_s.titleize
  end

  def key
    self.class.key_for(spec_code, parameter)
  end

  private

  def at_least_one_limit
    return if lower_limit.present? || upper_limit.present?

    errors.add(:base, "Enter at least one limit")
  end
end
