# frozen_string_literal: true

module ReportAi
  # Provider-agnostic interface for AI generation.
  # All generators must implement generate!(payload:, intent:)
  class Generator
    INTENTS = %w[work_summary commentary].freeze

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
    # @param intent [String] Either 'work_summary' or 'commentary'
    # @return [String] The generated text
    # @raise [GenerationError] On failure
    def generate!(payload:, intent:)
      raise NotImplementedError, "Subclasses must implement #generate!"
    end

    protected

    def validate_intent!(intent)
      unless INTENTS.include?(intent.to_s)
        raise ArgumentError, "Invalid intent: #{intent}. Must be one of: #{INTENTS.join(', ')}"
      end
    end
  end

  class GenerationError < StandardError; end
end
