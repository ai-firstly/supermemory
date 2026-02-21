# frozen_string_literal: true

module Supermemory
  module Resources
    class Settings < Base
      # Get current settings
      # @return [Hash]
      def get
        client.get("/v3/settings")
      end

      # Update settings
      # @param options [Hash] Settings to update
      # @option options [Integer, nil] :chunk_size
      # @option options [String, nil] :filter_prompt
      # @option options [Boolean, nil] :should_llm_filter
      # @option options [String, nil] :github_client_id
      # @option options [String, nil] :github_client_secret
      # @option options [Boolean, nil] :github_custom_key_enabled
      # @option options [String, nil] :google_drive_client_id
      # @option options [String, nil] :google_drive_client_secret
      # @option options [Boolean, nil] :google_drive_custom_key_enabled
      # @option options [String, nil] :notion_client_id
      # @option options [String, nil] :notion_client_secret
      # @option options [Boolean, nil] :notion_custom_key_enabled
      # @option options [String, nil] :onedrive_client_id
      # @option options [String, nil] :onedrive_client_secret
      # @option options [Boolean, nil] :onedrive_custom_key_enabled
      # @return [Hash]
      def update(**options)
        body = {}
        SETTINGS_KEY_MAP.each do |ruby_key, api_key|
          body[api_key] = options[ruby_key] if options.key?(ruby_key)
        end
        client.patch("/v3/settings", body)
      end

      SETTINGS_KEY_MAP = {
        chunk_size: :chunkSize,
        filter_prompt: :filterPrompt,
        should_llm_filter: :shouldLLMFilter,
        exclude_items: :excludeItems,
        include_items: :includeItems,
        github_client_id: :githubClientId,
        github_client_secret: :githubClientSecret,
        github_custom_key_enabled: :githubCustomKeyEnabled,
        google_drive_client_id: :googleDriveClientId,
        google_drive_client_secret: :googleDriveClientSecret,
        google_drive_custom_key_enabled: :googleDriveCustomKeyEnabled,
        notion_client_id: :notionClientId,
        notion_client_secret: :notionClientSecret,
        notion_custom_key_enabled: :notionCustomKeyEnabled,
        onedrive_client_id: :onedriveClientId,
        onedrive_client_secret: :onedriveClientSecret,
        onedrive_custom_key_enabled: :onedriveCustomKeyEnabled
      }.freeze
    end
  end
end
