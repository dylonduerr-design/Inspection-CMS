class WeeklyReport < ApplicationRecord
  belongs_to :project
  belongs_to :user

  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :project, presence: true
  validate :end_date_after_start_date

  enum status: { draft: 0, generated: 1, finalized: 2 }

  AI_STATUSES = %w[idle queued running success failed].freeze

  before_create :assign_report_number

  scope :for_project, ->(project_id) { where(project_id: project_id) }
  scope :chronological, -> { order(end_date: :desc) }

  # ----- Section 1 helpers (computed, not stored) -----

  # Total contract calendar days
  def contract_time
    project&.contract_days
  end

  # Cumulative count of distinct authorized working days from project start through end_date
  def days_charged
    return 0 unless project

    Report.where(project: project)
          .where.not(authorized_by_id: nil)
          .where(start_date: ..end_date)
          .distinct
          .count(:start_date)
  end

  # Latest authorized report date within this weekly period
  def last_working_day
    return nil unless project

    Report.where(project: project)
          .where.not(authorized_by_id: nil)
          .where(start_date: start_date..end_date)
          .maximum(:start_date)
  end

  def last_working_day_formatted
    day = last_working_day
    return "N/A" unless day

    day.strftime("%A, %-m/%-d/%Y")
  end

  # ----- AI helpers -----

  def ai_generating?
    ai_status.in?(%w[queued running])
  end

  def ai_can_generate?
    draft? || generated?
  end

  # ----- Section 3 helpers -----

  # Returns array of { name:, percent: } from cached completion_data_json
  def category_completions
    data = completion_data_json || {}
    (data["categories"] || []).map do |cat|
      { name: cat["name"], percent: cat["percent"] }
    end
  end

  def overall_completion_pct
    data = completion_data_json || {}
    data["overall_percent"] || 0.0
  end

  # Computed, formatted narrative for FAA Form 5370-1 Section 3.
  # Matches the desired format:
  # - Optional schedule sentence (based on project contract dates)
  # - "Estimated percent completion is X%."
  # - Bullets: "• Category: X%"
  def completion_narrative
    lines = []

    schedule = project_schedule_sentence
    lines << schedule if schedule.present?

    lines << "Estimated percent completion is #{format_percent(overall_completion_pct)}."

    category_completions.each do |cat|
      lines << "• #{cat[:name]}: #{format_percent(cat[:percent])}"
    end

    lines.join("\n")
  end

  # ----- Period helpers -----

  def period_label
    "#{start_date.strftime('%-m/%-d/%Y')} – #{end_date.strftime('%-m/%-d/%Y')}"
  end

  def authorized_reports
    Report.where(project: project)
          .where.not(authorized_by_id: nil)
          .where(start_date: start_date..end_date)
  end

  private

  def project_schedule_sentence
    return nil unless project
    return nil unless project.contract_start_date.present? && project.contract_days.to_i.positive?

    start = project.contract_start_date
    # Contract days are treated as inclusive calendar days.
    finish = start + (project.contract_days.to_i - 1)
    duration = project.contract_days.to_i

    "The Project is scheduled from #{start.strftime('%B %-d, %Y')} to #{finish.strftime('%B %-d, %Y')} for a total duration of #{duration} Calendar Days."
  end

  def format_percent(value)
    num = value.to_f
    formatted = (num % 1.0).zero? ? num.round(0).to_i.to_s : format('%.1f', num)
    "#{formatted}%"
  end

  def assign_report_number
    max = WeeklyReport.where(project_id: project_id).maximum(:report_number) || 0
    self.report_number = max + 1
  end

  def end_date_after_start_date
    return unless start_date && end_date

    if end_date < start_date
      errors.add(:end_date, "must be on or after start date")
    end
  end
end
