# frozen_string_literal: true

require "supermemory"

module Supermemory
  module Integrations
    # Integration with graph-agent (https://github.com/ai-firstly/graph-agent).
    #
    # Provides reusable node functions and a pre-built memory-augmented graph
    # for adding persistent memory to graph-agent workflows.
    #
    # @example Basic usage with pre-built nodes
    #   require "supermemory/integrations/graph_agent"
    #
    #   nodes = Supermemory::Integrations::GraphAgent::Nodes.new(
    #     api_key: ENV["SUPERMEMORY_API_KEY"]
    #   )
    #
    #   graph = GraphAgent::Graph::StateGraph.new(
    #     Supermemory::Integrations::GraphAgent.memory_schema
    #   )
    #   graph.add_node("recall", nodes.method(:recall_memories))
    #   graph.add_node("store", nodes.method(:store_memory))
    module GraphAgent
      # Build a state schema with memory fields
      # @param extra_fields [Hash] Additional field definitions to merge
      # @return [Hash] Schema hash compatible with GraphAgent::Graph::StateGraph
      def self.memory_schema(extra_fields: {})
        {
          messages: { type: Array, reducer: ->(a, b) { a + Array(b) }, default: [] },
          memories: { type: Array, reducer: ->(a, b) { a + Array(b) }, default: [] },
          memory_context: { type: String, default: "" },
          user_id: { type: String, default: "" }
        }.merge(extra_fields)
      end

      # Pre-built node functions for memory operations
      class Nodes
        attr_reader :client

        # @param api_key [String] Supermemory API key
        # @param base_url [String, nil] Custom API endpoint
        def initialize(api_key:, base_url: nil)
          @client = Supermemory::Client.new(api_key: api_key, base_url: base_url)
        end

        # Node: Recall memories based on the last user message.
        # Fetches user profile and relevant memories, stores them in state.
        #
        # @param state [Hash] Current graph state (must contain :messages and :user_id)
        # @param _config [Hash] Graph config (unused but accepted for arity compatibility)
        # @return [Hash] State update with :memories and :memory_context
        def recall_memories(state, _config = nil)
          user_id = state[:user_id]
          return { memories: [], memory_context: "" } unless user_id && !user_id.empty?

          query = extract_last_user_message(state[:messages])
          return { memories: [], memory_context: "" } unless query

          result = @client.profile(container_tag: user_id, q: query)

          static_facts = result.dig("profile", "static") || []
          dynamic_context = result.dig("profile", "dynamic") || []
          search_results = result.dig("searchResults", "results") || []

          memories = search_results.map { |r| r["memory"] || r["chunk"] }.compact

          context = build_context(static_facts, dynamic_context, memories)

          { memories: search_results, memory_context: context }
        rescue => e
          warn "[Supermemory::GraphAgent] Failed to recall memories: #{e.message}"
          { memories: [], memory_context: "" }
        end

        # Node: Store the latest conversation exchange as a memory.
        #
        # @param state [Hash] Current graph state
        # @param _config [Hash] Graph config
        # @return [Hash] Empty state update
        def store_memory(state, _config = nil)
          user_id = state[:user_id]
          return {} unless user_id && !user_id.empty?

          messages = state[:messages] || []
          user_msg = extract_last_user_message(messages)
          assistant_msg = extract_last_assistant_message(messages)

          content = if user_msg && assistant_msg
                      "User: #{user_msg}\nAssistant: #{assistant_msg}"
                    elsif user_msg
                      "User: #{user_msg}"
                    end

          if content
            @client.add(content: content, container_tag: user_id)
          end

          {}
        rescue => e
          warn "[Supermemory::GraphAgent] Failed to store memory: #{e.message}"
          {}
        end

        # Node: Search memories with a specific query.
        #
        # @param state [Hash] Current graph state (expects :query or last user message)
        # @param _config [Hash] Graph config
        # @return [Hash] State update with :memories
        def search_memories(state, _config = nil)
          user_id = state[:user_id]
          query = state[:query] || extract_last_user_message(state[:messages])
          return { memories: [] } unless user_id && query

          result = @client.search.memories(
            q: query,
            container_tag: user_id,
            search_mode: "hybrid",
            limit: 5
          )

          { memories: result["results"] || [] }
        rescue => e
          warn "[Supermemory::GraphAgent] Failed to search memories: #{e.message}"
          { memories: [] }
        end

        # Node: Add a specific piece of content to memory.
        #
        # @param state [Hash] Current graph state (expects :memory_content)
        # @param _config [Hash] Graph config
        # @return [Hash] Empty state update
        def add_memory(state, _config = nil)
          user_id = state[:user_id]
          content = state[:memory_content]
          return {} unless user_id && content

          metadata = state[:memory_metadata] || {}
          @client.add(content: content, container_tag: user_id, metadata: metadata)

          {}
        rescue => e
          warn "[Supermemory::GraphAgent] Failed to add memory: #{e.message}"
          {}
        end

        private

        def extract_last_user_message(messages)
          msg = Array(messages).reverse.find { |m| m[:role] == "user" || m["role"] == "user" }
          msg[:content] || msg["content"] if msg
        end

        def extract_last_assistant_message(messages)
          msg = Array(messages).reverse.find { |m| m[:role] == "assistant" || m["role"] == "assistant" }
          msg[:content] || msg["content"] if msg
        end

        def build_context(static_facts, dynamic_context, memories)
          parts = []
          parts << "User Background:\n#{static_facts.map { |f| "- #{f}" }.join("\n")}" if static_facts.any?
          parts << "Recent Context:\n#{dynamic_context.map { |c| "- #{c}" }.join("\n")}" if dynamic_context.any?
          parts << "Relevant Memories:\n#{memories.map { |m| "- #{m}" }.join("\n")}" if memories.any?
          parts.join("\n\n")
        end
      end

      # Build a complete memory-augmented graph
      #
      # @param api_key [String] Supermemory API key
      # @param llm_node [Proc] A callable that takes (state, config) and returns
      #   a state update with at least a new message in :messages
      # @param should_store [Proc, nil] Optional callable (state) -> Boolean
      #   to conditionally skip memory storage
      # @param extra_schema [Hash] Additional schema fields
      # @param base_url [String, nil] Custom API endpoint
      # @return [Object] Compiled graph (call .invoke or .stream)
      #
      # @example
      #   llm_node = ->(state, _config) {
      #     context = state[:memory_context]
      #     # ... call your LLM with context ...
      #     { messages: [{ role: "assistant", content: response }] }
      #   }
      #
      #   app = Supermemory::Integrations::GraphAgent.build_memory_graph(
      #     api_key: ENV["SUPERMEMORY_API_KEY"],
      #     llm_node: llm_node
      #   )
      #
      #   result = app.invoke(
      #     { messages: [{ role: "user", content: "Hi!" }], user_id: "user-123" }
      #   )
      def self.build_memory_graph(api_key:, llm_node:, should_store: nil, extra_schema: {}, base_url: nil)
        require "graph_agent"

        nodes = Nodes.new(api_key: api_key, base_url: base_url)
        schema = memory_schema(extra_fields: extra_schema)
        graph = ::GraphAgent::Graph::StateGraph.new(schema)

        graph.add_node("recall", nodes.method(:recall_memories))
        graph.add_node("generate", llm_node)
        graph.add_node("store", nodes.method(:store_memory))

        graph.add_edge(::GraphAgent::START, "recall")
        graph.add_edge("recall", "generate")

        if should_store
          graph.add_conditional_edges("generate", lambda { |state|
            should_store.call(state) ? "store" : ::GraphAgent::END_NODE.to_s
          })
        else
          graph.add_edge("generate", "store")
        end

        graph.add_edge("store", ::GraphAgent::END_NODE)

        graph.compile
      end
    end
  end
end
