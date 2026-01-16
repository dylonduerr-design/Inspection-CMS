class ReportAttachment < ApplicationRecord
  belongs_to :report
  
  # This replaces the old attachment logic
  has_one_attached :file
  
  # Validations
  validates :file, presence: true
end