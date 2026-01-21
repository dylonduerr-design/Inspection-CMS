# frozen_string_literal: true

# Configuration for ReportAi module
#
# Environment variables required for Azure OpenAI (production):
#   AZURE_OPENAI_ENDPOINT       - e.g., https://your-resource.openai.azure.com/
#   AZURE_OPENAI_API_KEY        - Your API key
#   AZURE_OPENAI_DEPLOYMENT_NAME - Your model deployment name
#   AZURE_OPENAI_API_VERSION    - e.g., 2024-12-01-preview
#
# In development/test, the FakeGenerator is used when Azure isn't configured.

Rails.application.config.after_initialize do
  if Rails.env.production?
    unless ReportAi::Generator.azure_configured?
      Rails.logger.warn(
        "[ReportAi] Azure OpenAI not configured. " \
        "Set AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_API_KEY, and AZURE_OPENAI_DEPLOYMENT_NAME " \
        "environment variables. Falling back to FakeGenerator."
      )
    end
  end
end
