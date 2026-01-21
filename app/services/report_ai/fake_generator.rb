# frozen_string_literal: true

module ReportAi
  # Fake generator for development and testing
  # Returns deterministic responses based on intent
  class FakeGenerator < Generator
    # @param payload [Hash] The canonical report payload from PayloadBuilder
    # @param intent [String] Either 'work_summary' or 'commentary'
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
  end
end
