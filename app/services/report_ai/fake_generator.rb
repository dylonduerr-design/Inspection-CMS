# frozen_string_literal: true

module ReportAi
  # Fake generator for development and testing
  # Returns deterministic responses based on intent
  class FakeGenerator < Generator
    # @param payload [Hash] The canonical report payload from PayloadBuilder
    # @param intent [String] One of ALL_INTENTS
    # @return [String] The generated text
    def generate!(payload:, intent:)
      validate_intent!(intent)

      # Simulate some processing time in development
      sleep(0.5) if Rails.env.development?

      case intent.to_s
      when 'work_summary'
        generate_fake_work_summary(payload)
      when 'commentary'
        generate_fake_commentary(payload)
      when 'weekly_weather'
        generate_fake_weekly_weather(payload)
      when 'weekly_work_summary'
        generate_fake_weekly_work_summary(payload)
      when 'weekly_lab_testing'
        generate_fake_weekly_lab_testing(payload)
      when 'weekly_materials'
        generate_fake_weekly_materials(payload)
      when 'weekly_problem_areas'
        generate_fake_weekly_problem_areas(payload)
      end
    end

    private

    def generate_fake_work_summary(payload)
      project_name = payload.dig(:project, :name) || 'the project'
      start_date = payload.dig(:report, :start_date) || 'today'
      bid_items = payload[:bid_items] || []
      
      if bid_items.any?
        items_text = bid_items.first(3).map do |item|
          "#{item[:description]} (#{item[:quantity]} #{item[:unit]})"
        end.join(", ")
        
        <<~SUMMARY
          On #{start_date}, construction activities continued on #{project_name}. Work included #{items_text}. #{bid_items.size} bid item(s) were recorded with quantities placed. All work was performed in accordance with project specifications and quality standards.
        SUMMARY
      else
        <<~SUMMARY
          On #{start_date}, inspection activities were conducted on #{project_name}. No bid item quantities were recorded for this period. Site conditions were documented and compliance monitoring was performed.
        SUMMARY
      end.strip
    end

    def generate_fake_commentary(payload)
      original_commentary = payload.dig(:narrative, :commentary) || ''
      project_name = payload.dig(:project, :name) || 'the project'
      deficiency = payload.dig(:compliance, :deficiency_status)
      
      base_text = if original_commentary.present?
        "Building upon the inspector's observations: #{original_commentary}"
      else
        "Inspection activities were conducted on #{project_name}."
      end

      compliance_text = <<~COMPLIANCE
        
        Compliance monitoring was performed across all required areas including traffic control, environmental controls, security measures, and SWPPP compliance. All items were reviewed and documented per project requirements.
      COMPLIANCE

      deficiency_text = if deficiency.present? && deficiency != 'no_deficiency'
        "\n\nNote: A deficiency was identified during this inspection period. Appropriate documentation has been filed and the contractor has been notified of required corrective actions."
      else
        "\n\nNo deficiencies were identified during this inspection period."
      end

      "#{base_text}#{compliance_text}#{deficiency_text}".strip
    end

    # ─── Fake weekly generators ──────────────────────────────────────

    def generate_fake_weekly_weather(payload)
      high = payload[:temp_high] || 'N/A'
      low = payload[:temp_low] || 'N/A'
      precip = payload[:precip_total] || 0.0
      "Temperatures during the reporting period ranged from #{low}°F to #{high}°F. " \
      "Total precipitation was #{precip} inches. " \
      "Weather conditions were generally favorable for construction operations."
    end

    def generate_fake_weekly_work_summary(payload)
      categories = payload[:categories] || []
      entries = payload[:daily_entries] || []
      if categories.any?
        lines = categories.map { |c| "#{c}:\n- Work activities continued in this category during the period." }
        lines.join("\n\n")
      elsif entries.any?
        "Construction activities continued during the reporting period across #{entries.size} working day(s). " \
        "All work was performed in accordance with project specifications."
      else
        "No work activities were recorded during this period."
      end
    end

    def generate_fake_weekly_lab_testing(payload)
      entries = payload.is_a?(Array) ? payload : []
      if entries.any?
        "A total of #{entries.size} test(s) were performed during the reporting period. " \
        "Results have been documented and are available for review."
      else
        "No laboratory or field testing was performed during this period."
      end
    end

    def generate_fake_weekly_materials(payload)
      entries = payload.is_a?(Array) ? payload : []
      if entries.any?
        "#{entries.size} material test(s) were identified as failing or out-of-tolerance during this period. " \
        "These materials may be subject to pay reduction per contract specifications."
      else
        "No materials subject to pay reduction during this period."
      end
    end

    def generate_fake_weekly_problem_areas(payload)
      deficiencies = payload[:deficiencies] || []
      safety = payload[:safety_issues] || []
      parts = []
      parts << "#{deficiencies.size} deficiency(ies) were identified during this period." if deficiencies.any?
      parts << "#{safety.size} safety incident(s) were reported during this period." if safety.any?
      parts.any? ? parts.join(" ") : "No problem areas or issues to report during this period."
    end
  end
end
