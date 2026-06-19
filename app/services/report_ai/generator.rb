# frozen_string_literal: true

module ReportAi
  # Provider-agnostic interface for AI generation.
  # All generators must implement generate!(payload:, intent:)
  class Generator
    INTENTS = %w[work_summary commentary commentary_outline].freeze
    WEEKLY_INTENTS = %w[weekly_weather weekly_work_summary weekly_work_summary_map weekly_lab_testing weekly_materials weekly_problem_areas].freeze
    ALL_INTENTS = (INTENTS + WEEKLY_INTENTS).freeze

    class << self
      # Factory method to get the appropriate generator for current environment
      def for_env
        if Rails.env.test? || !azure_configured?
          FakeGenerator.new
        else
          AzureGenerator.new
        end
      end

      def azure_configured?
        ENV['AZURE_OPENAI_ENDPOINT'].present? &&
          ENV['AZURE_OPENAI_API_KEY'].present? &&
          ENV['AZURE_OPENAI_DEPLOYMENT_NAME'].present?
      end
    end

    # Subclasses must implement this method
    # @param payload [Hash] The canonical report payload from PayloadBuilder
    # @param intent [String] One of ALL_INTENTS
    # @return [String] The generated text
    # @raise [GenerationError] On failure
    def generate!(payload:, intent:)
      raise NotImplementedError, "Subclasses must implement #generate!"
    end

    protected

    def validate_intent!(intent)
      unless ALL_INTENTS.include?(intent.to_s)
        raise ArgumentError, "Invalid intent: #{intent}. Must be one of: #{ALL_INTENTS.join(', ')}"
      end
    end
  end

  class GenerationError < StandardError; end
end
