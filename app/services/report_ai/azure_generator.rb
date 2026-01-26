# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module ReportAi
  # Azure OpenAI implementation of the Generator interface
  class AzureGenerator < Generator
    DEFAULT_TIMEOUT = 60
    MAX_TOKENS = 1000

    def initialize
      @endpoint = normalize_endpoint(ENV.fetch('AZURE_OPENAI_ENDPOINT'))
      @api_key = ENV.fetch('AZURE_OPENAI_API_KEY')
      @deployment_name = ENV.fetch('AZURE_OPENAI_DEPLOYMENT_NAME')
      @api_version = ENV.fetch('AZURE_OPENAI_API_VERSION', '2024-12-01-preview')
    end

    # @param payload [Hash] The canonical report payload from PayloadBuilder
    # @param intent [String] Either 'work_summary' or 'commentary'
    # @return [String] The generated text
    # @raise [GenerationError] On failure
    def generate!(payload:, intent:)
      validate_intent!(intent)

      system_prompt = PromptTemplates.system_prompt(intent: intent)
      user_prompt = PromptTemplates.render_user_prompt(intent: intent, payload: payload)

      messages = [
        { role: 'system', content: system_prompt },
        { role: 'user', content: user_prompt }
      ]

      response = call_azure_api(messages)
      extract_content(response)
    rescue StandardError => e
      Rails.logger.error("[ReportAi::AzureGenerator] Generation failed: #{e.message}")
      raise GenerationError, "AI generation failed: #{e.message}"
    end

    private

    def call_azure_api(messages)
      uri = build_uri
      request = build_request(uri, messages)
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = DEFAULT_TIMEOUT
      http.open_timeout = DEFAULT_TIMEOUT

      Rails.logger.info("[ReportAi::AzureGenerator] Calling Azure OpenAI API...")
      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        error_body = JSON.parse(response.body) rescue { 'error' => response.body }
        error_message = error_body.dig('error', 'message') || response.body
        raise GenerationError, "Azure API error (#{response.code}): #{error_message}"
      end

      JSON.parse(response.body)
    end

    def build_uri
      # Azure OpenAI endpoint format:
      # https://{resource-name}.openai.azure.com/openai/deployments/{deployment-name}/chat/completions?api-version={api-version}
      base = @endpoint.chomp('/')
      URI.parse("#{base}/openai/deployments/#{@deployment_name}/chat/completions?api-version=#{@api_version}")
    end

    def normalize_endpoint(raw_endpoint)
      raw = raw_endpoint.to_s.strip
      uri = URI.parse(raw)

      if uri.scheme.blank? || uri.host.blank?
        raise GenerationError, 'AZURE_OPENAI_ENDPOINT must be a full URL like https://your-resource.openai.azure.com/'
      end

      port = uri.port
      default_port = (uri.scheme == 'https' ? 443 : 80)
      origin = if port && port != default_port
                 "#{uri.scheme}://#{uri.host}:#{port}"
               else
                 "#{uri.scheme}://#{uri.host}"
               end

      origin
    rescue URI::InvalidURIError => e
      raise GenerationError, "Invalid AZURE_OPENAI_ENDPOINT: #{e.message}"
    end

    def build_request(uri, messages)
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['api-key'] = @api_key

      request.body = {
        messages: messages,
        max_completion_tokens: MAX_TOKENS,
        temperature: 0.7,
        top_p: 0.95,
        frequency_penalty: 0,
        presence_penalty: 0
      }.to_json

      request
    end

    def extract_content(response)
      content = response.dig('choices', 0, 'message', 'content')
      
      if content.blank?
        raise GenerationError, "No content in AI response"
      end

      content.strip
    end
  end
end
