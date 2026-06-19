class LabTestResult < ApplicationRecord
  RESULT_KIND_HMA_AIR_VOIDS = "hma_air_voids".freeze
  RESULT_KIND_CORE_COMPACTION = "core_compaction".freeze
  RESULT_KIND_CONCRETE_STRENGTH = "concrete_strength".freeze
  RESULT_KINDS = [
    RESULT_KIND_HMA_AIR_VOIDS,
    RESULT_KIND_CORE_COMPACTION,
    RESULT_KIND_CONCRETE_STRENGTH
  ].freeze

  RESULT_KIND_LABELS = {
    RESULT_KIND_HMA_AIR_VOIDS => "Mix Properties",
    RESULT_KIND_CORE_COMPACTION => "Compaction Cores",
    RESULT_KIND_CONCRETE_STRENGTH => "Concrete"
  }.freeze

  belongs_to :project
  belongs_to :lab_test_import
  belongs_to :asphalt_lot, optional: true
  belongs_to :report, optional: true
  belongs_to :created_by, class_name: "User", foreign_key: "created_by_id", optional: true

  enum result: { pass: "pass", fail: "fail" }
  enum :result_kind, {
    hma_air_voids: RESULT_KIND_HMA_AIR_VOIDS,
    core_compaction: RESULT_KIND_CORE_COMPACTION,
    concrete_strength: RESULT_KIND_CONCRETE_STRENGTH
  }, prefix: :kind

  before_validation :assign_result_kind, if: -> { result_kind.blank? }

  validates :spec_code, presence: true
  validates :result_kind, presence: true, inclusion: { in: RESULT_KINDS }

  scope :by_spec_code,  ->(code)     { where(spec_code: code) if code.present? }
  scope :by_result_kind, ->(kind)    { where(result_kind: kind) if kind.present? }
  scope :by_result,     ->(r)        { where(result: r) if r.present? }
  scope :by_asphalt_lot, ->(lot_id)  { where(asphalt_lot_id: lot_id) if lot_id.present? }
  scope :by_date_range, ->(from, to) { where(test_date: from..to) if from.present? && to.present? }

  def self.infer_result_kind(spec_code, data)
    data = data.is_a?(Hash) ? data : {}

    if data["core_id"].present?
      RESULT_KIND_CORE_COMPACTION
    elsif data.key?("air_voids_avg")
      RESULT_KIND_HMA_AIR_VOIDS
    elsif spec_code == "P-610"
      RESULT_KIND_CONCRETE_STRENGTH
    elsif spec_code == "P-403"
      RESULT_KIND_CORE_COMPACTION
    elsif spec_code == "P-401"
      RESULT_KIND_HMA_AIR_VOIDS
    end
  end

  def self.result_kind_label(kind)
    RESULT_KIND_LABELS[kind] || kind.to_s.titleize
  end

  def self.result_for_import(project:, spec_code:, result_kind:, data:, fallback: nil)
    if project_limit_driven?(spec_code, result_kind)
      derive_project_limit_result(project: project, spec_code: spec_code, result_kind: result_kind, data: data)
    else
      normalize_result(fallback) || derive_report_limit_result(spec_code: spec_code, result_kind: result_kind, data: data)
    end
  end

  def self.project_limit_driven?(spec_code, result_kind)
    spec_code == "P-401" &&
      [RESULT_KIND_HMA_AIR_VOIDS, RESULT_KIND_CORE_COMPACTION].include?(result_kind)
  end

  def self.derive_project_limit_result(project:, spec_code:, result_kind:, data:)
    return nil unless project && project_limit_driven?(spec_code, result_kind)

    data = data.is_a?(Hash) ? data : {}

    case result_kind
    when RESULT_KIND_HMA_AIR_VOIDS
      air_voids = numeric_value(data["air_voids_avg"])
      lower_limit, upper_limit = project_limits(project, "air_voids")
      return nil if air_voids.nil? || lower_limit.nil? || upper_limit.nil?

      air_voids >= lower_limit && air_voids <= upper_limit ? "pass" : "fail"
    when RESULT_KIND_CORE_COMPACTION
      compaction = numeric_value(data["compaction_pct"])
      parameter = core_limit_parameter(data["core_type"])
      lower_limit, = project_limits(project, parameter)
      return nil if compaction.nil? || lower_limit.nil?

      compaction >= lower_limit ? "pass" : "fail"
    end
  end

  def refresh_project_limit_result!
    return false unless self.class.project_limit_driven?(spec_code, result_kind)

    derived_result = self.class.derive_project_limit_result(
      project: project,
      spec_code: spec_code,
      result_kind: result_kind,
      data: data
    )
    return false if result == derived_result

    update!(result: derived_result)
  end

  private

  def self.normalize_result(value)
    normalized = value.to_s
    results.key?(normalized) ? normalized : nil
  end

  def self.derive_report_limit_result(spec_code:, result_kind:, data:)
    return nil unless result_kind == RESULT_KIND_CORE_COMPACTION

    data = data.is_a?(Hash) ? data : {}
    compaction = numeric_value(data["compaction_pct"])
    required = numeric_value(data["required_compaction_pct"])

    if required.nil? && spec_code == "P-403"
      required = core_limit_parameter(data["core_type"]) == "mat_density" ? 94.0 : 92.0
    end

    return nil if compaction.nil? || required.nil?

    compaction >= required ? "pass" : "fail"
  end

  def self.project_limits(project, parameter)
    return [nil, nil] if parameter.blank?

    limit = project.project_lab_test_limits.find_by(spec_code: "P-401", parameter: parameter)
    [limit&.lower_limit&.to_f, limit&.upper_limit&.to_f]
  end

  def self.core_limit_parameter(core_type)
    case core_type.to_s.downcase
    when "mat" then "mat_density"
    when "joint" then "joint_density"
    end
  end

  def self.numeric_value(value)
    return nil if value.blank?

    Float(value)
  rescue ArgumentError, TypeError
    nil
  end

  def assign_result_kind
    self.result_kind = self.class.infer_result_kind(spec_code, data)
  end
end
