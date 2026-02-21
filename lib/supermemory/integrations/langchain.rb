# frozen_string_literal: true

require "json"

begin
  require "langchain"
rescue LoadError
  raise LoadError.new("The langchainrb gem is required for Supermemory::Integrations::Langchain. " \
                      "Add `gem 'langchainrb'` to your Gemfile.")
end

module Supermemory
  module Integrations
    # Integration with langchainrb (https://github.com/patterns-ai-core/langchainrb).
    #
    # Provides:
    # 1. SupermemoryTool - A Langchain tool for memory operations via function calling
    # 2. SupermemoryMemory - A memory class for conversation-aware agents
    #
    # @example Using as a tool with Langchain::Assistant
    #   tool = Supermemory::Integrations::Langchain::SupermemoryTool.new(
    #     api_key: ENV["SUPERMEMORY_API_KEY"],
    #     container_tag: "user-123"
    #   )
    #
    #   assistant = Langchain::Assistant.new(
    #     llm: Langchain::LLM::OpenAI.new(api_key: ENV["OPENAI_API_KEY"]),
    #     tools: [tool],
    #     instructions: "You are a helpful assistant with memory."
    #   )
    #
    #   assistant.add_message_and_run!(content: "Remember I like Ruby")
    module Langchain
      # Langchain tool for Supermemory memory operations.
      # Extends Langchain::ToolDefinition to work with Langchain::Assistant.
      class SupermemoryTool
        extend ::Langchain::ToolDefinition

        define_function :search_memory,
                        description: "SupermemoryTool: Search the user's long-term memory. " \
                                     "Use to recall stored facts, preferences, or context." do
          property :query, type: "string",
                           description: "The question or topic to search for in memory", required: true
          property :limit, type: "integer",
                           description: "Maximum number of memories to return (default: 5)"
          property :search_mode, type: "string",
                                 description: "Search mode: 'memories', 'hybrid', or 'documents'",
                                 enum: %w[memories hybrid documents]
        end

        define_function :add_memory,
                        description: "SupermemoryTool: Save information to long-term memory. " \
                                     "Use when the user shares preferences or facts worth remembering." do
          property :content, type: "string",
                             description: "The information to save as a memory", required: true
          property :metadata, type: "object",
                              description: "Optional metadata to attach to the memory"
        end

        define_function :get_profile,
                        description: "SupermemoryTool: Get user profile with long-term facts and context. " \
                                     "Use to understand the user's background." do
          property :query, type: "string",
                           description: "Optional query to also search for relevant memories alongside the profile"
        end

        define_function :forget_memory,
                        description: "SupermemoryTool: Remove a specific memory from the user's long-term memory. " \
                                     "Use this when the user asks to forget or delete specific information." do
          property :content, type: "string",
                             description: "The exact content of the memory to forget", required: true
          property :reason, type: "string",
                            description: "Optional reason for forgetting this memory"
        end

        # @param api_key [String] Supermemory API key
        # @param container_tag [String] Container tag for scoping memories to a user/project
        # @param base_url [String, nil] Custom API endpoint
        def initialize(api_key:, container_tag:, base_url: nil)
          @client = Supermemory::Client.new(api_key: api_key, base_url: base_url)
          @container_tag = container_tag
        end

        attr_reader :client, :container_tag

        def search_memory(query:, limit: 5, search_mode: "hybrid")
          result = @client.search.memories(
            q: query,
            container_tag: @container_tag,
            search_mode: search_mode,
            limit: limit
          )

          memories = (result["results"] || []).map do |r|
            r["memory"] || r["chunk"] || ""
          end.compact

          tool_response(content: memories.any? ? memories.join("\n---\n") : "No relevant memories found.")
        end

        def add_memory(content:, metadata: nil)
          result = @client.add(
            content: content,
            container_tag: @container_tag,
            metadata: metadata
          )
          tool_response(content: "Memory saved (ID: #{result["id"]})")
        end

        def get_profile(query: nil)
          result = @client.profile(container_tag: @container_tag, q: query)

          static = result.dig("profile", "static") || []
          dynamic = result.dig("profile", "dynamic") || []

          parts = []
          parts << "Background: #{static.join("; ")}" if static.any?
          parts << "Recent context: #{dynamic.join("; ")}" if dynamic.any?

          if query && result["searchResults"]
            search_results = result.dig("searchResults", "results") || []
            memories = search_results.map { |r| r["memory"] || r["chunk"] }.compact
            parts << "Related: #{memories.join("; ")}" if memories.any?
          end

          tool_response(content: parts.any? ? parts.join("\n") : "No profile information available yet.")
        end

        def forget_memory(content:, reason: nil)
          result = @client.memories.forget(
            container_tag: @container_tag,
            content: content,
            reason: reason
          )
          tool_response(content: result["forgotten"] ? "Memory forgotten." : "Memory not found.")
        end

        private

        def tool_response(content: nil, image_url: nil)
          ::Langchain::ToolResponse.new(content: content, image_url: image_url)
        end
      end

      # Helper class for injecting memory context into Langchain conversations.
      # Use this for automatic memory retrieval/storage without explicit tool calling.
      #
      # @example
      #   memory = Supermemory::Integrations::Langchain::SupermemoryMemory.new(
      #     api_key: ENV["SUPERMEMORY_API_KEY"],
      #     container_tag: "user-123"
      #   )
      #
      #   # Get context for injection into system prompt
      #   context = memory.context(query: "user preferences")
      #
      #   # Store a conversation exchange
      #   memory.store(user_message: "I prefer dark mode", assistant_message: "Noted!")
      class SupermemoryMemory
        attr_reader :client, :container_tag

        # @param api_key [String] Supermemory API key
        # @param container_tag [String] Container tag for scoping
        # @param base_url [String, nil] Custom API endpoint
        def initialize(api_key:, container_tag:, base_url: nil)
          @client = Supermemory::Client.new(api_key: api_key, base_url: base_url)
          @container_tag = container_tag
        end

        # Retrieve memory context for a query
        # @param query [String, nil] Search query
        # @return [String] Formatted memory context
        def context(query: nil)
          result = @client.profile(container_tag: @container_tag, q: query)
          format_context(result)
        rescue => e
          warn "[Supermemory::Langchain] Failed to fetch context: #{e.message}"
          ""
        end

        # Store a conversation exchange
        # @param user_message [String] User's message
        # @param assistant_message [String, nil] Assistant's response
        # @param metadata [Hash, nil] Optional metadata
        def store(user_message:, assistant_message: nil, metadata: nil)
          content = if assistant_message
                      "User: #{user_message}\nAssistant: #{assistant_message}"
                    else
                      user_message
                    end

          @client.add(content: content, container_tag: @container_tag, metadata: metadata)
        rescue => e
          warn "[Supermemory::Langchain] Failed to store memory: #{e.message}"
        end

        # Search memories
        # @param query [String] Search query
        # @param limit [Integer] Max results
        # @return [Array<Hash>]
        def search(query:, limit: 5)
          result = @client.search.memories(
            q: query,
            container_tag: @container_tag,
            search_mode: "hybrid",
            limit: limit
          )
          result["results"] || []
        rescue => e
          warn "[Supermemory::Langchain] Failed to search: #{e.message}"
          []
        end

        private

        def format_context(result)
          static = result.dig("profile", "static") || []
          dynamic = result.dig("profile", "dynamic") || []
          search_results = result.dig("searchResults", "results") || []

          parts = []
          parts << "User Background:\n#{static.join("\n")}" if static.any?
          parts << "Recent Context:\n#{dynamic.join("\n")}" if dynamic.any?

          if search_results.any?
            memories = search_results.map { |r| r["memory"] || r["chunk"] }.compact
            parts << "Relevant Memories:\n#{memories.join("\n")}" if memories.any?
          end

          parts.join("\n\n")
        end
      end
    end
  end
end
