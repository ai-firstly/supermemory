# frozen_string_literal: true

require "supermemory/integrations/openai"

RSpec.describe Supermemory::Integrations::OpenAI do
  let(:api_key) { "test-api-key" }
  let(:base_url) { "https://api.supermemory.ai" }

  describe Supermemory::Integrations::OpenAI::SupermemoryTools do
    let(:tools) { described_class.new(api_key: api_key, config: { container_tag: "user-1" }) }

    describe "#initialize" do
      it "creates a client" do
        expect(tools.api_key).to eq(api_key)
        expect(tools.config).to eq({ container_tag: "user-1" })
      end
    end

    describe "#get_tool_definitions" do
      it "returns 2 tool definitions" do
        definitions = tools.get_tool_definitions
        expect(definitions.size).to eq(2)
        names = definitions.map { |d| d[:function][:name] }
        expect(names).to eq(%w[searchMemories addMemory])
      end
    end

    describe "#search_memories" do
      it "calls search.memories API" do
        stub_request(:post, "#{base_url}/v4/search")
          .with(body: hash_including("q" => "ruby tips", "limit" => 5, "containerTag" => "user-1"))
          .to_return(status: 200, body: {
            results: [{ id: "m1", memory: "Use frozen_string_literal", similarity: 0.9 }],
            timing: 10,
            total: 1
          }.to_json)

        result = tools.search_memories(information_to_get: "ruby tips", limit: 5)
        expect(result["results"].first["memory"]).to eq("Use frozen_string_literal")
      end

      it "calls search.documents API when include_full_docs is true" do
        stub_request(:post, "#{base_url}/v3/search")
          .with(body: hash_including("q" => "ruby tips", "includeFullDocs" => true))
          .to_return(status: 200, body: {
            results: [{ documentId: "d1", score: 0.95, chunks: [] }],
            timing: 20,
            total: 1
          }.to_json)

        result = tools.search_memories(information_to_get: "ruby tips", include_full_docs: true)
        expect(result["results"].first["documentId"]).to eq("d1")
      end
    end

    describe "#add_memory" do
      it "calls add API" do
        stub_request(:post, "#{base_url}/v3/documents")
          .with(body: hash_including("content" => "I like Ruby", "containerTag" => "user-1"))
          .to_return(status: 200, body: { id: "doc-1", status: "processing" }.to_json)

        result = tools.add_memory(memory: "I like Ruby")
        expect(result["id"]).to eq("doc-1")
      end
    end

    describe "#execute_tool_call" do
      it "executes searchMemories tool call" do
        stub_request(:post, "#{base_url}/v4/search")
          .to_return(status: 200, body: { results: [], timing: 5, total: 0 }.to_json)

        tool_call = {
          "id" => "call_123",
          "function" => {
            "name" => "searchMemories",
            "arguments" => { information_to_get: "hobbies", limit: 3 }.to_json
          }
        }

        result = tools.execute_tool_call(tool_call)
        expect(result[:tool_call_id]).to eq("call_123")
        expect(result[:role]).to eq("tool")
        expect(result[:name]).to eq("searchMemories")
      end

      it "executes addMemory tool call" do
        stub_request(:post, "#{base_url}/v3/documents")
          .to_return(status: 200, body: { id: "doc-2", status: "processing" }.to_json)

        tool_call = {
          "id" => "call_456",
          "function" => {
            "name" => "addMemory",
            "arguments" => { memory: "Loves hiking" }.to_json
          }
        }

        result = tools.execute_tool_call(tool_call)
        expect(result[:tool_call_id]).to eq("call_456")
        expect(result[:name]).to eq("addMemory")
        parsed = JSON.parse(result[:content])
        expect(parsed["id"]).to eq("doc-2")
      end

      it "returns error for unknown tool" do
        tool_call = {
          "id" => "call_789",
          "function" => {
            "name" => "unknownTool",
            "arguments" => {}.to_json
          }
        }

        result = tools.execute_tool_call(tool_call)
        parsed = JSON.parse(result[:content])
        expect(parsed["error"]).to include("Unknown tool")
      end
    end
  end

  describe ".execute_memory_tool_calls" do
    it "processes searchMemories and addMemory tool calls" do
      stub_request(:post, "#{base_url}/v4/search")
        .to_return(status: 200, body: { results: [], timing: 5, total: 0 }.to_json)
      stub_request(:post, "#{base_url}/v3/documents")
        .to_return(status: 200, body: { id: "doc-1", status: "processing" }.to_json)

      tool_calls = [
        { "id" => "c1", "function" => { "name" => "searchMemories",
                                        "arguments" => { information_to_get: "test" }.to_json } },
        { "id" => "c2", "function" => { "name" => "addMemory",
                                        "arguments" => { memory: "note" }.to_json } }
      ]

      results = described_class.execute_memory_tool_calls(api_key: api_key, tool_calls: tool_calls)
      expect(results.size).to eq(2)
      expect(results.map { |r| r[:name] }).to eq(%w[searchMemories addMemory])
    end

    it "filters out non-memory tool calls" do
      tool_calls = [
        { "id" => "c1", "function" => { "name" => "getWeather",
                                        "arguments" => { city: "NYC" }.to_json } },
        { "id" => "c2", "function" => { "name" => "searchMemories",
                                        "arguments" => { information_to_get: "test" }.to_json } }
      ]

      stub_request(:post, "#{base_url}/v4/search")
        .to_return(status: 200, body: { results: [], timing: 5, total: 0 }.to_json)

      results = described_class.execute_memory_tool_calls(api_key: api_key, tool_calls: tool_calls)
      expect(results.size).to eq(1)
      expect(results.first[:name]).to eq("searchMemories")
    end
  end

  describe Supermemory::Integrations::OpenAI::WrappedClient do
    let(:openai_response) do
      {
        "choices" => [
          { "message" => { "role" => "assistant", "content" => "Hello there!" } }
        ]
      }
    end
    let(:mock_openai) do
      double("OpenAI::Client").tap do |client|
        allow(client).to receive(:chat).and_return(openai_response)
        allow(client).to receive(:models).and_return("models_data")
      end
    end
    let(:user_id) { "user-42" }

    describe "#initialize" do
      it "creates internal supermemory client" do
        wrapped = described_class.new(mock_openai, user_id, api_key: api_key)
        expect(wrapped.openai_client).to eq(mock_openai)
      end
    end

    describe "#chat" do
      context "in profile mode" do
        it "fetches profile and injects into system message" do
          stub_request(:post, "#{base_url}/v4/profile")
            .with(body: hash_including("container_tag" => user_id))
            .to_return(status: 200, body: {
              profile: { static: ["Likes Ruby"], dynamic: ["Working on gems"] }
            }.to_json)
          stub_request(:post, "#{base_url}/v3/documents")
            .to_return(status: 200, body: { id: "d1", status: "processing" }.to_json)

          wrapped = described_class.new(mock_openai, user_id, api_key: api_key, mode: "profile")
          wrapped.chat(parameters: {
            messages: [
              { role: "user", content: "Hi" }
            ]
          })

          expect(mock_openai).to have_received(:chat) do |args|
            messages = args[:parameters][:messages]
            system_msg = messages.find { |m| m[:role] == "system" }
            expect(system_msg[:content]).to include("User Memory Context")
            expect(system_msg[:content]).to include("Likes Ruby")
          end
        end
      end

      context "in query mode" do
        it "searches memories and injects results" do
          stub_request(:post, "#{base_url}/v4/search")
            .with(body: hash_including("q" => "What are my hobbies?", "containerTag" => user_id))
            .to_return(status: 200, body: {
              results: [{ memory: "Enjoys hiking" }],
              timing: 10,
              total: 1
            }.to_json)
          stub_request(:post, "#{base_url}/v3/documents")
            .to_return(status: 200, body: { id: "d1", status: "processing" }.to_json)

          wrapped = described_class.new(mock_openai, user_id, api_key: api_key, mode: "query")
          wrapped.chat(parameters: {
            messages: [
              { role: "user", content: "What are my hobbies?" }
            ]
          })

          expect(mock_openai).to have_received(:chat) do |args|
            messages = args[:parameters][:messages]
            system_msg = messages.find { |m| m[:role] == "system" }
            expect(system_msg[:content]).to include("Relevant Memories")
            expect(system_msg[:content]).to include("Enjoys hiking")
          end
        end
      end

      context "in full mode" do
        it "fetches profile with query" do
          stub_request(:post, "#{base_url}/v4/profile")
            .with(body: hash_including("container_tag" => user_id, "q" => "Tell me about myself"))
            .to_return(status: 200, body: {
              profile: { static: ["Developer"], dynamic: [] },
              searchResults: { results: [{ memory: "Works at Acme" }] }
            }.to_json)
          stub_request(:post, "#{base_url}/v3/documents")
            .to_return(status: 200, body: { id: "d1", status: "processing" }.to_json)

          wrapped = described_class.new(mock_openai, user_id, api_key: api_key, mode: "full")
          wrapped.chat(parameters: {
            messages: [
              { role: "user", content: "Tell me about myself" }
            ]
          })

          expect(mock_openai).to have_received(:chat) do |args|
            messages = args[:parameters][:messages]
            system_msg = messages.find { |m| m[:role] == "system" }
            expect(system_msg[:content]).to include("Developer")
            expect(system_msg[:content]).to include("Works at Acme")
          end
        end
      end

      it "stores conversation when add_memory is always" do
        stub_request(:post, "#{base_url}/v4/profile")
          .to_return(status: 200, body: {
            profile: { static: [], dynamic: [] },
            searchResults: { results: [] }
          }.to_json)
        add_stub = stub_request(:post, "#{base_url}/v3/documents")
                   .with(body: hash_including("content" => /User:.*Assistant:/m, "containerTag" => user_id))
                   .to_return(status: 200, body: { id: "d1", status: "processing" }.to_json)

        wrapped = described_class.new(mock_openai, user_id, api_key: api_key, add_memory: "always")
        wrapped.chat(parameters: {
          messages: [{ role: "user", content: "Remember this" }]
        })

        expect(add_stub).to have_been_requested
      end

      it "does NOT store conversation when add_memory is never" do
        stub_request(:post, "#{base_url}/v4/profile")
          .to_return(status: 200, body: {
            profile: { static: [], dynamic: [] },
            searchResults: { results: [] }
          }.to_json)

        wrapped = described_class.new(mock_openai, user_id, api_key: api_key, add_memory: "never")
        wrapped.chat(parameters: {
          messages: [{ role: "user", content: "Don't remember this" }]
        })

        expect(WebMock).not_to have_requested(:post, "#{base_url}/v3/documents")
      end

      it "injects context into existing system message" do
        stub_request(:post, "#{base_url}/v4/profile")
          .to_return(status: 200, body: {
            profile: { static: ["Knows Ruby"], dynamic: [] },
            searchResults: { results: [] }
          }.to_json)
        stub_request(:post, "#{base_url}/v3/documents")
          .to_return(status: 200, body: { id: "d1", status: "processing" }.to_json)

        wrapped = described_class.new(mock_openai, user_id, api_key: api_key)
        wrapped.chat(parameters: {
          messages: [
            { role: "system", content: "You are a helpful assistant." },
            { role: "user", content: "Hi" }
          ]
        })

        expect(mock_openai).to have_received(:chat) do |args|
          messages = args[:parameters][:messages]
          system_msg = messages.find { |m| m[:role] == "system" }
          expect(system_msg[:content]).to start_with("You are a helpful assistant.")
          expect(system_msg[:content]).to include("User Memory Context")
        end
      end

      it "adds system message when none exists" do
        stub_request(:post, "#{base_url}/v4/profile")
          .to_return(status: 200, body: {
            profile: { static: ["Knows Ruby"], dynamic: [] },
            searchResults: { results: [] }
          }.to_json)
        stub_request(:post, "#{base_url}/v3/documents")
          .to_return(status: 200, body: { id: "d1", status: "processing" }.to_json)

        wrapped = described_class.new(mock_openai, user_id, api_key: api_key)
        wrapped.chat(parameters: {
          messages: [
            { role: "user", content: "Hi" }
          ]
        })

        expect(mock_openai).to have_received(:chat) do |args|
          messages = args[:parameters][:messages]
          expect(messages.first[:role]).to eq("system")
          expect(messages.first[:content]).to include("User Memory Context")
        end
      end

      it "handles API errors gracefully and returns nil context" do
        stub_request(:post, "#{base_url}/v4/profile")
          .to_return(status: 500, body: { error: "Internal Server Error" }.to_json)

        wrapped = described_class.new(mock_openai, user_id, api_key: api_key,
                                                            add_memory: "never", verbose: false)
        response = wrapped.chat(parameters: {
          messages: [{ role: "user", content: "Hi" }]
        })

        # Should still call OpenAI without injected context
        expect(mock_openai).to have_received(:chat) do |args|
          messages = args[:parameters][:messages]
          expect(messages.none? { |m| (m[:role] || m["role"]) == "system" }).to be true
        end
        expect(response).to eq(openai_response)
      end
    end

    describe "#respond_to_missing?" do
      it "delegates to wrapped client" do
        wrapped = described_class.new(mock_openai, user_id, api_key: api_key)
        expect(wrapped.respond_to?(:models)).to be true
        expect(wrapped.respond_to?(:nonexistent_method)).to be false
      end
    end

    describe "method_missing" do
      it "delegates to wrapped client" do
        wrapped = described_class.new(mock_openai, user_id, api_key: api_key)
        expect(wrapped.models).to eq("models_data")
      end
    end

    describe "format helpers" do
      it "format_profile returns nil when no profile data" do
        stub_request(:post, "#{base_url}/v4/profile")
          .to_return(status: 200, body: {
            profile: { static: [], dynamic: [] },
            searchResults: { results: [] }
          }.to_json)

        wrapped = described_class.new(mock_openai, user_id, api_key: api_key, mode: "profile",
                                                            add_memory: "never")
        wrapped.chat(parameters: {
          messages: [{ role: "user", content: "Hi" }]
        })

        # No context should be injected since profile is empty
        expect(mock_openai).to have_received(:chat) do |args|
          messages = args[:parameters][:messages]
          expect(messages.none? { |m| (m[:role] || m["role"]) == "system" }).to be true
        end
      end

      it "format_search_results returns nil when no results" do
        stub_request(:post, "#{base_url}/v4/search")
          .to_return(status: 200, body: { results: [], timing: 5, total: 0 }.to_json)

        wrapped = described_class.new(mock_openai, user_id, api_key: api_key, mode: "query",
                                                            add_memory: "never")
        wrapped.chat(parameters: {
          messages: [{ role: "user", content: "Hi" }]
        })

        expect(mock_openai).to have_received(:chat) do |args|
          messages = args[:parameters][:messages]
          expect(messages.none? { |m| (m[:role] || m["role"]) == "system" }).to be true
        end
      end
    end
  end
end
