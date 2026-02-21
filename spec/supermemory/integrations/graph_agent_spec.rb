# frozen_string_literal: true

require "supermemory/integrations/graph_agent"

RSpec.describe Supermemory::Integrations::GraphAgent do
  describe ".memory_schema" do
    subject(:schema) { described_class.memory_schema }

    it "returns a hash with :messages, :memories, :memory_context, :user_id fields" do
      expect(schema.keys).to contain_exactly(:messages, :memories, :memory_context, :user_id)
    end

    it "defines :messages with type Array, a reducer, and default []" do
      field = schema[:messages]
      expect(field[:type]).to eq(Array)
      expect(field[:default]).to eq([])
      expect(field[:reducer]).to respond_to(:call)
    end

    it "defines :memories with type Array, a reducer, and default []" do
      field = schema[:memories]
      expect(field[:type]).to eq(Array)
      expect(field[:default]).to eq([])
      expect(field[:reducer]).to respond_to(:call)
    end

    it "defines :memory_context with type String and default empty string" do
      field = schema[:memory_context]
      expect(field[:type]).to eq(String)
      expect(field[:default]).to eq("")
    end

    it "defines :user_id with type String and default empty string" do
      field = schema[:user_id]
      expect(field[:type]).to eq(String)
      expect(field[:default]).to eq("")
    end

    it "reducer for :messages appends arrays" do
      reducer = schema[:messages][:reducer]
      expect(reducer.call([1], [2, 3])).to eq([1, 2, 3])
    end

    it "reducer for :memories appends arrays" do
      reducer = schema[:memories][:reducer]
      expect(reducer.call(["a"], ["b"])).to eq(%w[a b])
    end

    it "merges extra_fields" do
      schema = described_class.memory_schema(extra_fields: { custom: { type: Integer, default: 0 } })
      expect(schema).to have_key(:custom)
      expect(schema[:custom][:type]).to eq(Integer)
    end
  end

  describe Supermemory::Integrations::GraphAgent::Nodes do
    let(:api_key) { "test-key" }
    let(:base_url) { "https://api.supermemory.ai" }
    let(:nodes) { described_class.new(api_key: api_key, base_url: base_url) }

    describe "#initialize" do
      it "creates a Supermemory::Client" do
        expect(nodes.client).to be_a(Supermemory::Client)
      end
    end

    describe "#recall_memories" do
      it "returns memories and context from the profile API" do
        stub_request(:post, "#{base_url}/v4/profile")
          .with(body: hash_including("container_tag" => "user-1", "q" => "Hello"))
          .to_return(status: 200, body: {
            profile: { static: ["likes Ruby"], dynamic: ["building SDK"] },
            searchResults: { results: [{ "memory" => "previous chat" }] }
          }.to_json)

        state = { user_id: "user-1", messages: [{ role: "user", content: "Hello" }] }
        result = nodes.recall_memories(state)

        expect(result[:memories]).to eq([{ "memory" => "previous chat" }])
        expect(result[:memory_context]).to include("likes Ruby")
        expect(result[:memory_context]).to include("building SDK")
        expect(result[:memory_context]).to include("previous chat")
      end

      it "returns empty when user_id is empty" do
        state = { user_id: "", messages: [{ role: "user", content: "Hi" }] }
        result = nodes.recall_memories(state)

        expect(result).to eq({ memories: [], memory_context: "" })
      end

      it "returns empty when there are no messages" do
        state = { user_id: "user-1", messages: [] }
        result = nodes.recall_memories(state)

        expect(result).to eq({ memories: [], memory_context: "" })
      end

      it "handles API errors gracefully" do
        stub_request(:post, "#{base_url}/v4/profile")
          .to_return(status: 500, body: { error: "Server error" }.to_json)

        state = { user_id: "user-1", messages: [{ role: "user", content: "Hi" }] }
        expect { nodes.recall_memories(state) }.not_to raise_error

        result = nodes.recall_memories(state)
        expect(result).to eq({ memories: [], memory_context: "" })
      end
    end

    describe "#store_memory" do
      it "stores user and assistant messages" do
        stub = stub_request(:post, "#{base_url}/v3/documents")
               .with(body: hash_including(
                 "content" => "User: Hi\nAssistant: Hello!",
                 "containerTag" => "user-1"
               ))
               .to_return(status: 200, body: { id: "doc-1", status: "queued" }.to_json)

        state = {
          user_id: "user-1",
          messages: [
            { role: "user", content: "Hi" },
            { role: "assistant", content: "Hello!" }
          ]
        }
        result = nodes.store_memory(state)

        expect(result).to eq({})
        expect(stub).to have_been_requested
      end

      it "stores only user message when no assistant message exists" do
        stub = stub_request(:post, "#{base_url}/v3/documents")
               .with(body: hash_including(
                 "content" => "User: Hi",
                 "containerTag" => "user-1"
               ))
               .to_return(status: 200, body: { id: "doc-2", status: "queued" }.to_json)

        state = {
          user_id: "user-1",
          messages: [{ role: "user", content: "Hi" }]
        }
        result = nodes.store_memory(state)

        expect(result).to eq({})
        expect(stub).to have_been_requested
      end

      it "returns empty hash when user_id is empty" do
        state = { user_id: "", messages: [{ role: "user", content: "Hi" }] }
        result = nodes.store_memory(state)

        expect(result).to eq({})
      end

      it "handles API errors gracefully" do
        stub_request(:post, "#{base_url}/v3/documents")
          .to_return(status: 500, body: { error: "Server error" }.to_json)

        state = {
          user_id: "user-1",
          messages: [{ role: "user", content: "Hi" }]
        }
        expect { nodes.store_memory(state) }.not_to raise_error

        result = nodes.store_memory(state)
        expect(result).to eq({})
      end
    end

    describe "#search_memories" do
      it "searches with a query from state" do
        stub_request(:post, "#{base_url}/v4/search")
          .with(body: hash_including("q" => "Ruby tips", "containerTag" => "user-1"))
          .to_return(status: 200, body: {
            results: [{ id: "m1", memory: "Use frozen_string_literal", similarity: 0.9 }],
            timing: 10,
            total: 1
          }.to_json)

        state = { user_id: "user-1", query: "Ruby tips", messages: [] }
        result = nodes.search_memories(state)

        expect(result[:memories]).to eq([{ "id" => "m1", "memory" => "Use frozen_string_literal", "similarity" => 0.9 }])
      end

      it "uses last user message when no :query in state" do
        stub_request(:post, "#{base_url}/v4/search")
          .with(body: hash_including("q" => "What is Ruby?"))
          .to_return(status: 200, body: {
            results: [{ id: "m2", memory: "A programming language" }],
            timing: 5,
            total: 1
          }.to_json)

        state = {
          user_id: "user-1",
          messages: [{ role: "user", content: "What is Ruby?" }]
        }
        result = nodes.search_memories(state)

        expect(result[:memories].first["memory"]).to eq("A programming language")
      end

      it "returns empty when user_id is missing" do
        state = { user_id: nil, messages: [{ role: "user", content: "Hi" }] }
        result = nodes.search_memories(state)

        expect(result).to eq({ memories: [] })
      end
    end

    describe "#add_memory" do
      it "adds memory content via the documents API" do
        stub = stub_request(:post, "#{base_url}/v3/documents")
               .with(body: hash_including(
                 "content" => "Important fact",
                 "containerTag" => "user-1"
               ))
               .to_return(status: 200, body: { id: "doc-3", status: "queued" }.to_json)

        state = { user_id: "user-1", memory_content: "Important fact" }
        result = nodes.add_memory(state)

        expect(result).to eq({})
        expect(stub).to have_been_requested
      end

      it "returns empty hash when memory_content is nil" do
        state = { user_id: "user-1", memory_content: nil }
        result = nodes.add_memory(state)

        expect(result).to eq({})
      end

      it "handles API errors gracefully" do
        stub_request(:post, "#{base_url}/v3/documents")
          .to_return(status: 500, body: { error: "Server error" }.to_json)

        state = { user_id: "user-1", memory_content: "fact" }
        expect { nodes.add_memory(state) }.not_to raise_error

        result = nodes.add_memory(state)
        expect(result).to eq({})
      end
    end
  end
end
