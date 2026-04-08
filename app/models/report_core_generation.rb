class ReportCoreGeneration < ApplicationRecord
  belongs_to :report
  belongs_to :core_generation

  validates :core_generation_id, uniqueness: { scope: :report_id }

  after_create :log_seed_to_audit

  private

  def log_seed_to_audit
    return unless report.user.present?

    lot = core_generation.asphalt_lot
    AuditLog.create!(
      report: report,
      user: report.user,
      note: "Core locations attached \u2014 Seed: #{core_generation.seed}, Generation ##{core_generation.id}, Lot ##{lot.lot_number}"
    )
  end
end
