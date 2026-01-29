class ImportedReport < ApplicationRecord
  belongs_to :user
  belongs_to :project, optional: true

  has_one_attached :source_docx
  has_many_attached :photos

  enum status: {
    imported: "imported",
    needs_review: "needs_review",
    rejected: "rejected"
  }

  validates :status, presence: true
end
