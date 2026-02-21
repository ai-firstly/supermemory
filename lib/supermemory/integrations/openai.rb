# frozen_string_literal: true

require "json"
require "supermemory"

module Supermemory
  module Integrations
    # Integration with the ruby-openai gem (https://github.com/alexrudall/ruby-openai).
    #
    # Provides two approaches:
    # 1. SupermemoryTools - Function calling tools for explicit memory operations
    # 2. with_supermemory - Wrapper that auto-injects memories into system prompts
    module OpenAI
      # Tool definitions for OpenAI function calling
      class SupermemoryTools
        SEARCH_MEMORIES_TOOL = {
          type: "function",
          function: {
            name: "searchMemories",
            description: "Search through user memories for relevant information. " \
                         "Use this when the user asks a question that might be answered by their stored memories.",
            parameters: {
              type: "object",
              properties: {
                information_to_get: {
                  type: "string",
                  description: "What information to search for in the user's memories"
                },
                limit: {
                  type: "integer",
                  description: "Maximum number of memories to return (default: 10)"
                }
              },
              required: ["information_to_get"]
            }
          }
        }.freeze

        ADD_MEMORY_TOOL = {
          type: "function",
          function: {
            name: "addMemory",
            description: "Save important information to the user's long-term memory. " \
                         "Use when the user shares preferences, facts, or information worth remembering.",
            parameters: {
              type: "object",
              properties: {
                memory: {
                  type: "string",
                  description: "The information to save as a memory"
                }
              },
              required: ["memory"]
            }
          }
        }.freeze

        attr_reader :api_key, :config

        # @param api_key [String] Supermemory API key
        # @param config [Hash] Configuration options
        # @option config [String] :container_tag Container tag for scoping memories
        # @option config [String] :base_url Custom API endpoint
        def initialize(api_key:, config: {})
          @api_key = api_key
          @config = config
          @client = Supermemory::Client.new(
            api_key: api_key,
            base_url: config[:base_url]
          )
        end

        # Get tool definitions for OpenAI function calling
        # @return [Array<Hash>]
        def get_tool_definitions
          [SEARCH_MEMORIES_TOOL, ADD_MEMORY_TOOL]
        end

        # Search memories
        # @param information_to_get [String] Query string
        # @param limit [Integer] Max results
        # @param include_full_docs [Boolean]
        # @return [Hash]
        def search_memories(information_to_get:, limit: 10, include_full_docs: false)
          params = { q: information_to_get, limit: limit }
          params[:container_tag] = config[:container_tag] if config[:container_tag]

          if include_full_docs
            @client.search.documents(q: information_to_get, limit: limit,
                                     include_full_docs: true)
          else
            @client.search.memories(**params)
          end
        end

        # Add a memory
        # @param memory [String] Content to remember
        # @return [Hash]
        def add_memory(memory:)
          options = {}
          options[:container_tag] = config[:container_tag] if config[:container_tag]
          @client.add(content: memory, **options)
        end

        # Execute a single tool call from an OpenAI response
        # @param tool_call [Hash] Tool call from OpenAI response
        # @return [Hash] { tool_call_id:, role: "tool", name:, content: }
        def execute_tool_call(tool_call)
          function_name = tool_call.dig("function", "name")
          arguments = JSON.parse(tool_call.dig("function", "arguments"), symbolize_names: true)

          result = case function_name
                   when "searchMemories"
                     search_memories(
                       information_to_get: arguments[:information_to_get],
                       limit: arguments[:limit] || 10
                     )
                   when "addMemory"
                     add_memory(memory: arguments[:memory])
                   else
                     { error: "Unknown tool: #{function_name}" }
                   end

          {
            tool_call_id: tool_call["id"],
            role: "tool",
            name: function_name,
            content: result.to_json
          }
        end
      end

      # Execute memory tool calls from an OpenAI response
      # @param api_key [String] Supermemory API key
      # @param tool_calls [Array<Hash>] Tool calls from OpenAI response
      # @param config [Hash] Configuration options
      # @return [Array<Hash>] Tool result messages
      def self.execute_memory_tool_calls(api_key:, tool_calls:, config: {})
        tools = SupermemoryTools.new(api_key: api_key, config: config)
        memory_tool_names = %w[searchMemories addMemory]

        tool_calls.select { |tc| memory_tool_names.include?(tc.dig("function", "name")) }
                  .map { |tc| tools.execute_tool_call(tc) }
      end

      # Wrap an OpenAI client to automatically inject memories into system prompts
      #
      # @param openai_client [OpenAI::Client] A ruby-openai client instance
      # @param user_id [String] User identifier (used as container_tag)
      # @param options [Hash] Configuration
      # @option options [String] :mode "profile", "query", or "full" (default: "full")
      # @option options [String] :add_memory "always" or "never" (default: "always")
      # @option options [Boolean] :verbose Enable debug logging (default: false)
      # @option options [String] :base_url Custom API endpoint
      # @return [WrappedClient]
      def self.with_supermemory(openai_client, user_id, options = {})
        WrappedClient.new(openai_client, user_id, options)
      end

      # A wrapper around OpenAI::Client that auto-injects memories
      class WrappedClient
        attr_reader :openai_client

        def initialize(openai_client, user_id, options = {})
          @openai_client = openai_client
          @user_id = user_id
          @mode = options.fetch(:mode, "full")
          @add_memory = options.fetch(:add_memory, "always")
          @verbose = options.fetch(:verbose, false)
          @supermemory = Supermemory::Client.new(
            api_key: options[:api_key] || ENV.fetch("SUPERMEMORY_API_KEY", nil),
            base_url: options[:base_url]
          )
        end

        # Intercept chat calls to inject memory context
        # @param parameters [Hash] OpenAI chat parameters
        # @return [Hash] OpenAI response
        def chat(parameters:)
          messages = parameters[:messages] || parameters["messages"] || []
          user_message = find_last_user_message(messages)

          if user_message
            context = fetch_memory_context(user_message)
            parameters = inject_context(parameters, context) if context
          end

          response = @openai_client.chat(parameters: parameters)

          if @add_memory == "always" && user_message
            store_conversation(user_message, response)
          end

          response
        end

        # Delegate all other methods to the wrapped client
        def method_missing(method, ...)
          @openai_client.send(method, ...)
        end

        def respond_to_missing?(method, include_private = false)
          @openai_client.respond_to?(method, include_private) || super
        end

        private

        def find_last_user_message(messages)
          user_msgs = messages.select { |m| m[:role] == "user" || m["role"] == "user" }
          msg = user_msgs.last
          msg[:content] || msg["content"] if msg
        end

        def fetch_memory_context(query)
          case @mode
          when "profile"
            result = @supermemory.profile(container_tag: @user_id)
            format_profile(result)
          when "query"
            result = @supermemory.search.memories(q: query, container_tag: @user_id, limit: 5)
            format_search_results(result)
          when "full"
            result = @supermemory.profile(container_tag: @user_id, q: query)
            format_full(result)
          end
        rescue => e
          warn "[Supermemory] Failed to fetch context: #{e.message}" if @verbose
          nil
        end

        def inject_context(parameters, context)
          parameters = parameters.dup
          messages = (parameters[:messages] || parameters["messages"]).dup

          system_idx = messages.index { |m| (m[:role] || m["role"]) == "system" }
          if system_idx
            msg = messages[system_idx].dup
            content = msg[:content] || msg["content"]
            msg_key = msg.key?(:content) ? :content : "content"
            msg[msg_key] = "#{content}\n\n#{context}"
            messages[system_idx] = msg
          else
            messages.unshift({ role: "system", content: context })
          end

          key = parameters.key?(:messages) ? :messages : "messages"
          parameters[key] = messages
          parameters
        end

        def store_conversation(user_message, response)
          assistant_content = response.dig("choices", 0, "message", "content")
          return unless assistant_content

          @supermemory.add(
            content: "User: #{user_message}\nAssistant: #{assistant_content}",
            container_tag: @user_id
          )
        rescue => e
          warn "[Supermemory] Failed to store conversation: #{e.message}" if @verbose
        end

        def format_profile(result)
          static = result.dig("profile", "static") || []
          dynamic = result.dig("profile", "dynamic") || []
          parts = []
          parts << "User Background:\n#{static.join("\n")}" if static.any?
          parts << "Recent Context:\n#{dynamic.join("\n")}" if dynamic.any?
          parts.any? ? "[User Memory Context]\n#{parts.join("\n\n")}" : nil
        end

        def format_search_results(result)
          results = result["results"] || []
          return nil if results.empty?

          memories = results.map { |r| r["memory"] || r["chunk"] }.compact
          "[Relevant Memories]\n#{memories.join("\n")}"
        end

        def format_full(result)
          profile_text = format_profile(result)
          search = result.dig("searchResults", "results") || []
          memory_text = if search.any?
                          memories = search.map { |r| r["memory"] || r["chunk"] }.compact
                          "Relevant Memories:\n#{memories.join("\n")}" if memories.any?
                        end

          parts = [profile_text, memory_text].compact
          parts.any? ? "[User Memory Context]\n#{parts.join("\n\n")}" : nil
        end
      end
    end
  end
end
