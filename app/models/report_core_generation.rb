class ReportCoreGeneration < ApplicationRecord
  belongs_to :report
  belongs_to :core_generation

  validates :core_generation_id, uniqueness: { scope: :report_id }
end
