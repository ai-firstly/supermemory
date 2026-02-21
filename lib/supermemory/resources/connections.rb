# frozen_string_literal: true

module Supermemory
  module Resources
    class Connections < Base
      PROVIDERS = %w[notion google-drive onedrive gmail github web-crawler s3].freeze

      # Create a connection (returns OAuth auth URL)
      # @param provider [String] Provider name
      # @param container_tags [Array<String>, nil]
      # @param document_limit [Integer, nil]
      # @param metadata [Hash, nil]
      # @param redirect_url [String, nil]
      # @return [Hash] { "id" => "...", "authLink" => "...", "expiresIn" => "..." }
      def create(provider, container_tags: nil, document_limit: nil, metadata: nil, redirect_url: nil)
        body = {}
        body[:containerTags] = container_tags if container_tags
        body[:documentLimit] = document_limit if document_limit
        body[:metadata] = metadata if metadata
        body[:redirectUrl] = redirect_url if redirect_url
        client.post("/v3/connections/#{provider}", body)
      end

      # List connections
      # @param container_tags [Array<String>, nil]
      # @return [Array<Hash>]
      def list(container_tags: nil)
        body = {}
        body[:containerTags] = container_tags if container_tags
        client.post("/v3/connections/list", body)
      end

      # Configure a connection (e.g., GitHub resources)
      # @param connection_id [String]
      # @param resources [Array<Hash>]
      # @return [Hash] { "message" => "...", "success" => true/false }
      def configure(connection_id, resources:)
        client.post("/v3/connections/#{connection_id}/configure", { resources: resources })
      end

      # Get connection by ID
      # @param connection_id [String]
      # @return [Hash]
      def get_by_id(connection_id)
        client.get("/v3/connections/#{connection_id}")
      end

      # Get connection by provider and tags
      # @param provider [String]
      # @param container_tags [Array<String>]
      # @return [Hash]
      def get_by_tag(provider, container_tags:)
        client.post("/v3/connections/#{provider}/connection", { containerTags: container_tags })
      end

      # Delete connection by ID
      # @param connection_id [String]
      # @return [Hash]
      def delete_by_id(connection_id)
        client.delete("/v3/connections/#{connection_id}")
      end

      # Delete connection by provider
      # @param provider [String]
      # @param container_tags [Array<String>]
      # @return [Hash]
      def delete_by_provider(provider, container_tags:)
        client.delete("/v3/connections/#{provider}", { containerTags: container_tags })
      end

      # Trigger manual import/sync
      # @param provider [String]
      # @param container_tags [Array<String>, nil]
      # @return [String]
      def import(provider, container_tags: nil)
        body = {}
        body[:containerTags] = container_tags if container_tags
        client.post("/v3/connections/#{provider}/import", body)
      end

      # List documents for a connection
      # @param provider [String]
      # @param container_tags [Array<String>, nil]
      # @return [Array<Hash>]
      def list_documents(provider, container_tags: nil)
        body = {}
        body[:containerTags] = container_tags if container_tags
        client.post("/v3/connections/#{provider}/documents", body)
      end

      # Get available resources for a connection
      # @param connection_id [String]
      # @param page [Integer, nil]
      # @param per_page [Integer, nil]
      # @return [Hash] { "resources" => [...], "total_count" => ... }
      def resources(connection_id, page: nil, per_page: nil)
        params = {}
        params[:page] = page if page
        params[:per_page] = per_page if per_page
        client.get("/v3/connections/#{connection_id}/resources", params)
      end
    end
  end
end
