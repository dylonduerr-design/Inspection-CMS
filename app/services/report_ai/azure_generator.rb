# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module ReportAi
  # Azure OpenAI implementation of the Generator interface
  class AzureGenerator < Generator
    DEFAULT_TIMEOUT = 180
    MAX_TOKENS = 16_000  # Must be high enough for reasoning models (e.g. gpt-5-nano)
                         # where max_completion_tokens covers BOTH reasoning + output.

    def initialize
      @endpoint = normalize_endpoint(ENV.fetch('AZURE_OPENAI_ENDPOINT'))
      @api_key = ENV.fetch('AZURE_OPENAI_API_KEY')
      @deployment_name = ENV.fetch('AZURE_OPENAI_DEPLOYMENT_NAME')
      @api_version = ENV.fetch('AZURE_OPENAI_API_VERSION', '2024-12-01-preview')
      @on_stage_change = nil
    end

    # Optional callback invoked when the commentary pipeline transitions stages.
    # Set this before calling generate! to receive stage notifications.
    attr_writer :on_stage_change

    # Approximate token threshold for triggering chunked (map-reduce) generation.
    # When the formatted daily_entries exceed this, we split into batches.
    CHUNK_CHAR_THRESHOLD = 6_000  # ~1,500 tokens
    CHUNK_BATCH_SIZE = 2          # days per batch in map pass

    # @param payload [Hash] The canonical report payload from PayloadBuilder
    # @param intent [String] One of Generator::ALL_INTENTS
    # @return [String] The generated text
    # @raise [GenerationError] On failure
    def generate!(payload:, intent:)
      validate_intent!(intent)

      # For weekly_work_summary, check whether the input is large enough to
      # require a two-pass map-reduce approach.
      if intent.to_s == 'weekly_work_summary' && needs_chunking?(payload)
        return generate_chunked_work_summary(payload)
      end

      # Commentary uses a two-pass pipeline: outline extraction then writing
      if intent.to_s == 'commentary'
        return generate_commentary_with_outline!(payload)
      end

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
        max_completion_tokens: MAX_TOKENS
      }.to_json

      request
    end

    def extract_content(response)
      choice = response.dig('choices', 0)
      message = choice&.dig('message')
      content = message&.dig('content')
      finish_reason = choice&.dig('finish_reason')

      # Handle truncated responses (finish_reason: "length")
      if finish_reason == 'length'
        if content.present?
          Rails.logger.warn("[ReportAi::AzureGenerator] Response truncated (finish_reason: length). Returning partial content.")
          return content.strip
        else
          Rails.logger.error("[ReportAi::AzureGenerator] Empty content with finish_reason: length. Input likely too large.")
          raise GenerationError,
            "Response exceeded token limit — the input data may be too large. " \
            "Try reducing the reporting period or editing this section manually."
        end
      end

      if content.blank?
        Rails.logger.error("[ReportAi::AzureGenerator] Empty content. Full response: #{response.inspect}")

        if finish_reason == 'content_filter'
          raise GenerationError, "AI generation failed due to content filter."
        end

        raise GenerationError, "No content in AI response. Finish reason: #{finish_reason.inspect}"
      end

      content.strip
    end

    # ─── Two-pass commentary pipeline with RAG ─────────────────────────────────────

    def generate_commentary_with_outline!(payload)
      # Pass 1 — extraction
      Rails.logger.info("[ReportAi::AzureGenerator] Commentary Pass 1: extracting outline")
      sys1 = PromptTemplates.system_prompt(intent: 'commentary_outline')
      usr1 = PromptTemplates.render_user_prompt(intent: 'commentary_outline', payload: payload)
      outline_response = call_azure_api([
        { role: 'system', content: sys1 },
        { role: 'user',   content: usr1 }
      ])
      outline = extract_content(outline_response)

      # RAG: Retrieve relevant FAA standards based on the outline
      faa_context = retrieve_faa_standards_context(outline, payload)

      # Notify the job of stage transition (if a callback is set)
      @on_stage_change&.call('writing')

      # Pass 2 — writing with FAA standards context
      Rails.logger.info("[ReportAi::AzureGenerator] Commentary Pass 2: writing commentary with RAG context")
      outline_payload = payload.merge(
        commentary_outline: outline,
        faa_standards_context: faa_context
      )
      sys2 = PromptTemplates.system_prompt(intent: 'commentary')
      usr2 = PromptTemplates.render_user_prompt(intent: 'commentary', payload: outline_payload)
      writing_response = call_azure_api([
        { role: 'system', content: sys2 },
        { role: 'user',   content: usr2 }
      ])
      final = extract_content(writing_response)

      { outline: outline, commentary: final }
    end

    # Retrieve relevant FAA standards context using RAG
    def retrieve_faa_standards_context(outline, payload)
      # Only retrieve if the vector store has data
      return '' unless FaaStandardsChunk.exists?

      # Build a query from the outline and bid items
      query_parts = [outline]

      # Add bid item descriptions to the query for better retrieval
      if payload[:bid_items].present?
        bid_item_codes = payload[:bid_items].map { |item| item[:code] }.compact.join(', ')
        query_parts << "Bid items: #{bid_item_codes}"
      end

      query = query_parts.join("\n")

      # Initialize the RAG retriever
      retriever = FaaRag::Retriever.new(top_k: 5)

      # Retrieve and format context
      context = retriever.retrieve_context(query)

      Rails.logger.info("[ReportAi::AzureGenerator] Retrieved FAA standards context: #{context.length} chars")
      context
    rescue StandardError => e
      Rails.logger.warn("[ReportAi::AzureGenerator] RAG retrieval failed, continuing without context: #{e.message}")
      ''  # Return empty string on error to avoid breaking generation
    end

    # ─── Chunked (map-reduce) generation for large work summaries ───

    def needs_chunking?(payload)
      entries = payload[:daily_entries]
      return false unless entries.is_a?(Array) && entries.size > CHUNK_BATCH_SIZE

      # Estimate the total character count of all entries
      total_chars = entries.sum do |e|
        (e[:summary].to_s.length) + (e[:additional_activities].to_s.length)
      end

      total_chars > CHUNK_CHAR_THRESHOLD
    end

    # Two-pass generation:
    #   Pass 1 (map):   Split daily entries into batches → condense each batch into bullets
    #   Pass 2 (reduce): Feed all condensed bullets into the final weekly_work_summary prompt
    def generate_chunked_work_summary(payload)
      entries = payload[:daily_entries]
      categories = payload[:categories]

      batches = entries.each_slice(CHUNK_BATCH_SIZE).to_a
      Rails.logger.info("[ReportAi::AzureGenerator] Chunked work summary: #{entries.size} entries → #{batches.size} batches")

      # Pass 1: Map — condense each batch
      condensed_parts = batches.map.with_index do |batch, idx|
        Rails.logger.info("[ReportAi::AzureGenerator]   Map pass #{idx + 1}/#{batches.size}")
        batch_payload = { daily_entries: batch, categories: categories }

        sys = PromptTemplates.system_prompt(intent: 'weekly_work_summary_map')
        usr = PromptTemplates.render_user_prompt(intent: 'weekly_work_summary_map', payload: batch_payload)

        response = call_azure_api([
          { role: 'system', content: sys },
          { role: 'user', content: usr }
        ])
        extract_content(response)
      end

      # Pass 2: Reduce — synthesize condensed bullets into the final summary
      Rails.logger.info("[ReportAi::AzureGenerator]   Reduce pass (#{condensed_parts.size} partial summaries)")

      combined_summary = condensed_parts.map.with_index do |part, idx|
        "--- Batch #{idx + 1} ---\n#{part}"
      end.join("\n\n")

      reduce_payload = {
        daily_entries: [{ date: 'consolidated', summary: combined_summary }],
        categories: categories
      }

      sys = PromptTemplates.system_prompt(intent: 'weekly_work_summary')
      usr = PromptTemplates.render_user_prompt(intent: 'weekly_work_summary', payload: reduce_payload)

      response = call_azure_api([
        { role: 'system', content: sys },
        { role: 'user', content: usr }
      ])
      extract_content(response)
    end
  end
end
