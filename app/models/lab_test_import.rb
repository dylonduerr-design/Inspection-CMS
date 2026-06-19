class LabTestImport < ApplicationRecord
  SPEC_CODES = %w[P-401 P-403 P-610].freeze
  ASPHALT_SPEC_CODES = %w[P-401 P-403].freeze
  CONCRETE_SPEC_CODES = %w[P-610].freeze
  RESULT_KINDS = %w[hma_air_voids core_compaction concrete_strength].freeze
  MAX_PDF_SIZE = 10.megabytes

  belongs_to :project
  belongs_to :user
  belongs_to :asphalt_lot, optional: true
  belongs_to :report, optional: true
  has_one_attached :source_pdf
  has_many :lab_test_results, dependent: :nullify

  validate :asphalt_lot_belongs_to_project
  validate :report_belongs_to_project

  enum status: {
    pending:      "pending",
    needs_review: "needs_review",
    saved:        "saved",
    rejected:     "rejected"
  }

  enum :result_kind, {
    hma_air_voids: "hma_air_voids",
    core_compaction: "core_compaction",
    concrete_strength: "concrete_strength"
  }, prefix: :kind

  validates :spec_code, presence: true, inclusion: { in: SPEC_CODES }
  validates :status, presence: true
  validates :result_kind, inclusion: { in: RESULT_KINDS }, allow_nil: true
  validate  :source_pdf_attached_and_valid

  def broadcast_status
    ActionCable.server.broadcast(
      "lab_test_import:#{id}",
      {
        id: id,
        status: status,
        result_kind: result_kind,
        row_count: row_count,
        lab_name: lab_name,
        errors: extraction_errors
      }
    )
  end

  private

  def asphalt_lot_belongs_to_project
    return if asphalt_lot.blank?
    if asphalt_lot.project_id != project_id
      errors.add(:asphalt_lot, "must belong to the same project")
    end
  end

  def report_belongs_to_project
    return if report.blank?
    if report.project_id != project_id
      errors.add(:report, "must belong to the same project")
    end
  end

  def source_pdf_attached_and_valid
    return errors.add(:source_pdf, "is required") unless source_pdf.attached?

    if source_pdf.blob.byte_size > MAX_PDF_SIZE
      errors.add(:source_pdf, "must be smaller than #{MAX_PDF_SIZE / 1.megabyte}MB")
    end

    unless source_pdf.blob.content_type == "application/pdf"
      errors.add(:source_pdf, "must be a PDF")
    end
  end
end
