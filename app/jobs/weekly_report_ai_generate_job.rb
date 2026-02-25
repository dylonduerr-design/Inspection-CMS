# frozen_string_literal: true

class WeeklyReportAiGenerateJob < ApplicationJob
  queue_as :default

  INTENT_FIELD_MAP = {
    'weekly_weather'      => :weather_summary,
    'weekly_work_summary' => :work_summary,
    'weekly_lab_testing'  => :lab_testing_summary,
    'weekly_materials'    => :materials_summary,
    'weekly_problem_areas' => :problem_areas
  }.freeze

  # @param weekly_report_id [Integer] The weekly report to generate AI content for
  # @param intent [String] One of the INTENT_FIELD_MAP keys
  # @param user_id [Integer] The user who triggered the generation (for audit)
  def perform(weekly_report_id, intent, user_id)
    weekly_report = WeeklyReport.find_by(id: weekly_report_id)
    user = User.find_by(id: user_id)

    unless weekly_report
      Rails.logger.warn("[WeeklyReportAiGenerateJob] WeeklyReport #{weekly_report_id} not found, skipping")
      return
    end

    field = INTENT_FIELD_MAP[intent.to_s]
    unless field
      Rails.logger.warn("[WeeklyReportAiGenerateJob] Unknown intent: #{intent}, skipping")
      return
    end

    Rails.logger.info("[WeeklyReportAiGenerateJob] Starting #{intent} generation for weekly_report #{weekly_report_id}")

    begin
      # Mark as running
      weekly_report.update_columns(ai_status: 'running', ai_error: nil)

      # Build payload from the service
      service = WeeklyReportService.new(weekly_report)
      payload = build_payload(service, intent)

      # Generate using appropriate provider
      generator = ReportAi::Generator.for_env
      result = generator.generate!(payload: payload, intent: intent)

      # Persist result
      weekly_report.update_columns(field => result)

      # Check if all sections are now populated — if so, mark as success
      weekly_report.reload
      if all_sections_generated?(weekly_report)
        weekly_report.update_columns(ai_status: 'success')
        weekly_report.update_columns(status: WeeklyReport.statuses[:generated]) if weekly_report.draft?
      end

      Rails.logger.info("[WeeklyReportAiGenerateJob] Successfully generated #{intent} for weekly_report #{weekly_report_id}")

    rescue ReportAi::GenerationError => e
      handle_failure(weekly_report, intent, e.message)
    rescue StandardError => e
      Rails.logger.error("[WeeklyReportAiGenerateJob] Unexpected error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      handle_failure(weekly_report, intent, "Unexpected error: #{e.message}")
    end
  end

  private

  def build_payload(service, intent)
    case intent.to_s
    when 'weekly_weather'
      service.weather_payload.deep_symbolize_keys
    when 'weekly_work_summary'
      service.work_summary_payload.deep_symbolize_keys
    when 'weekly_lab_testing'
      service.lab_testing_payload
    when 'weekly_materials'
      service.materials_payload
    when 'weekly_problem_areas'
      service.problem_areas_payload.deep_symbolize_keys
    else
      {}
    end
  end

  def all_sections_generated?(weekly_report)
    INTENT_FIELD_MAP.values.all? { |field| weekly_report.send(field).present? }
  end

  def handle_failure(weekly_report, intent, error_message)
    Rails.logger.error("[WeeklyReportAiGenerateJob] Failed #{intent} for weekly_report #{weekly_report.id}: #{error_message}")

    weekly_report.update_columns(
      ai_status: 'failed',
      ai_error: "#{intent}: #{error_message}"
    )
  end
end
