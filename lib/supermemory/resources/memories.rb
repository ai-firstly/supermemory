# frozen_string_literal: true

module Supermemory
  module Resources
    class Memories < Base
      # Forget (soft-delete) a memory
      # @param container_tag [String] Scope identifier
      # @param id [String, nil] Memory ID (use id or content)
      # @param content [String, nil] Exact content match (alternative to id)
      # @param reason [String, nil] Optional reason for forgetting
      # @return [Hash] { "id" => "...", "forgotten" => true/false }
      def forget(container_tag:, id: nil, content: nil, reason: nil)
        body = { containerTag: container_tag }
        body[:id] = id if id
        body[:content] = content if content
        body[:reason] = reason if reason
        client.delete("/v4/memories", body)
      end

      # Update a memory (creates a new version)
      # @param container_tag [String] Scope identifier
      # @param new_content [String] Replacement content
      # @param id [String, nil] Target memory ID
      # @param content [String, nil] Exact content match for lookup
      # @param metadata [Hash, nil] Metadata for the new version
      # @return [Hash] { "id" => "...", "memory" => "...", "version" => ... }
      def update_memory(container_tag:, new_content:, id: nil, content: nil, metadata: nil)
        body = { containerTag: container_tag, newContent: new_content }
        body[:id] = id if id
        body[:content] = content if content
        body[:metadata] = metadata if metadata
        client.patch("/v4/memories", body)
      end
    end
  end
end
