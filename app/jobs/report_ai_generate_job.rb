# frozen_string_literal: true

class ReportAiGenerateJob < ApplicationJob
  queue_as :default

  # @param report_id [Integer] The report to generate AI content for
  # @param intent [String] Either 'work_summary' or 'commentary'
  # @param user_id [Integer] The user who triggered the generation (for audit)
  def perform(report_id, intent, user_id)
    report = Report.find_by(id: report_id)
    user = User.find_by(id: user_id)

    unless report
      Rails.logger.warn("[ReportAiGenerateJob] Report #{report_id} not found, skipping")
      return
    end

    Rails.logger.info("[ReportAiGenerateJob] Starting #{intent} generation for report #{report_id} (user: #{user_id})")

    begin
      # Mark as running
      report.update_columns(ai_status: 'running', ai_error: nil)

      # Build payload
      payload = ReportAi::PayloadBuilder.build(report)

      # Generate using appropriate provider
      generator = ReportAi::Generator.for_env
      result = generator.generate!(payload: payload, intent: intent)

      # Persist result based on intent
      update_attrs = {
        ai_status: 'success',
        ai_generated_at: Time.current,
        ai_error: nil
      }

      case intent.to_s
      when 'work_summary'
        update_attrs[:ai_work_summary] = result
      when 'commentary'
        update_attrs[:ai_generated_commentary] = result
      end

      report.update_columns(update_attrs)

      # Create audit log
      if user
        AuditLog.create(
          report: report,
          user: user,
          note: "AI #{intent.humanize} generated successfully"
        )
      end

      Rails.logger.info("[ReportAiGenerateJob] Successfully generated #{intent} for report #{report_id}")

    rescue ReportAi::GenerationError => e
      handle_failure(report, user, intent, e.message)
    rescue StandardError => e
      Rails.logger.error("[ReportAiGenerateJob] Unexpected error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      handle_failure(report, user, intent, "Unexpected error: #{e.message}")
    end
  end

  private

  def handle_failure(report, user, intent, error_message)
    Rails.logger.error("[ReportAiGenerateJob] Failed #{intent} generation for report #{report.id}: #{error_message}")

    report.update_columns(
      ai_status: 'failed',
      ai_error: error_message
    )

    if user
      AuditLog.create(
        report: report,
        user: user,
        note: "AI #{intent.humanize} generation failed: #{error_message}"
      )
    end
  end
end
