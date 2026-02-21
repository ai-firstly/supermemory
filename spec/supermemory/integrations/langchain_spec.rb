# frozen_string_literal: true

require "supermemory/integrations/langchain"

RSpec.describe Supermemory::Integrations::Langchain do
  describe Supermemory::Integrations::Langchain::SupermemoryTool do
    let(:api_key) { "test-api-key" }
    let(:container_tag) { "user-123" }
    let(:base_url) { "https://api.supermemory.ai" }

    # Skip tests if langchain gem is not available
    before do
      skip "langchainrb gem not available" unless defined?(Langchain::ToolDefinition)
    end

    describe "#initialize" do
      it "creates a Supermemory client" do
        tool = described_class.new(api_key: api_key, container_tag: container_tag)
        expect(tool.client).to be_a(Supermemory::Client)
        expect(tool.container_tag).to eq(container_tag)
      end

      it "accepts custom base_url" do
        tool = described_class.new(
          api_key: api_key,
          container_tag: container_tag,
          base_url: "https://custom.api.com"
        )
        expect(tool.client.base_url).to eq("https://custom.api.com")
      end
    end

    describe "#search_memory" do
      it "searches memories via v4 API" do
        stub_request(:post, "#{base_url}/v4/search")
          .with(body: hash_including(
            "q" => "ruby programming",
            "containerTag" => container_tag,
            "searchMode" => "hybrid",
            "limit" => 5
          ))
          .to_return(status: 200, body: {
            results: [
              { id: "m1", memory: "Uses Ruby daily", similarity: 0.9 },
              { id: "m2", memory: "Prefers functional programming", similarity: 0.8 }
            ],
            timing: 10,
            total: 2
          }.to_json)

        tool = described_class.new(api_key: api_key, container_tag: container_tag)
        result = tool.search_memory(query: "ruby programming", limit: 5)

        expect(result.content).to include("Uses Ruby daily")
        expect(result.content).to include("Prefers functional programming")
      end

      it "returns 'No relevant memories found' when no results" do
        stub_request(:post, "#{base_url}/v4/search")
          .to_return(status: 200, body: { results: [], timing: 5, total: 0 }.to_json)

        tool = described_class.new(api_key: api_key, container_tag: container_tag)
        result = tool.search_memory(query: "nothing", limit: 5)

        expect(result.content).to eq("No relevant memories found.")
      end

      it "handles different search modes" do
        stub_request(:post, "#{base_url}/v4/search")
          .with(body: hash_including("searchMode" => "memories"))
          .to_return(status: 200, body: { results: [], timing: 5, total: 0 }.to_json)

        tool = described_class.new(api_key: api_key, container_tag: container_tag)
        tool.search_memory(query: "test", search_mode: "memories")
      end

      it "handles chunks when memory field is missing" do
        stub_request(:post, "#{base_url}/v4/search")
          .to_return(status: 200, body: {
            results: [
              { id: "c1", chunk: "A chunk of text", similarity: 0.85 }
            ],
            timing: 10,
            total: 1
          }.to_json)

        tool = described_class.new(api_key: api_key, container_tag: container_tag)
        result = tool.search_memory(query: "test")

        expect(result.content).to include("A chunk of text")
      end
    end

    describe "#add_memory" do
      it "adds a document via the API" do
        stub_request(:post, "#{base_url}/v3/documents")
          .with(body: hash_including(
            "content" => "User prefers dark mode",
            "containerTag" => container_tag
          ))
          .to_return(status: 200, body: { id: "doc-1", status: "queued" }.to_json)

        tool = described_class.new(api_key: api_key, container_tag: container_tag)
        result = tool.add_memory(content: "User prefers dark mode")

        expect(result.content).to include("doc-1")
        expect(result.content).to include("saved")
      end

      it "accepts metadata" do
        stub_request(:post, "#{base_url}/v3/documents")
          .with(body: hash_including("metadata" => { "source" => "chat" }))
          .to_return(status: 200, body: { id: "doc-2", status: "queued" }.to_json)

        tool = described_class.new(api_key: api_key, container_tag: container_tag)
        result = tool.add_memory(content: "Test", metadata: { "source" => "chat" })

        expect(result.content).to include("doc-2")
      end
    end

    describe "#get_profile" do
      it "fetches user profile" do
        stub_request(:post, "#{base_url}/v4/profile")
          .with(body: hash_including("container_tag" => container_tag))
          .to_return(status: 200, body: {
            profile: {
              static: ["Developer", "10 years experience"],
              dynamic: ["Working on AI project"]
            }
          }.to_json)

        tool = described_class.new(api_key: api_key, container_tag: container_tag)
        result = tool.get_profile

        expect(result.content).to include("Developer")
        expect(result.content).to include("10 years experience")
        expect(result.content).to include("Working on AI project")
      end

      it "includes search results when query is provided" do
        stub_request(:post, "#{base_url}/v4/profile")
          .with(body: hash_including("q" => "coding"))
          .to_return(status: 200, body: {
            profile: { static: [], dynamic: [] },
            searchResults: {
              results: [
                { memory: "Prefers Ruby over Python" },
                { memory: "Likes TDD" }
              ]
            }
          }.to_json)

        tool = described_class.new(api_key: api_key, container_tag: container_tag)
        result = tool.get_profile(query: "coding")

        expect(result.content).to include("Prefers Ruby over Python")
        expect(result.content).to include("Likes TDD")
      end

      it "returns message when no profile information" do
        stub_request(:post, "#{base_url}/v4/profile")
          .to_return(status: 200, body: {
            profile: { static: [], dynamic: [] }
          }.to_json)

        tool = described_class.new(api_key: api_key, container_tag: container_tag)
        result = tool.get_profile

        expect(result.content).to include("No profile information available")
      end
    end

    describe "#forget_memory" do
      it "forgets a memory by content" do
        stub_request(:delete, "#{base_url}/v4/memories")
          .with(body: hash_including(
            "containerTag" => container_tag,
            "content" => "Old preference"
          ))
          .to_return(status: 200, body: { id: "mem-1", forgotten: true }.to_json)

        tool = described_class.new(api_key: api_key, container_tag: container_tag)
        result = tool.forget_memory(content: "Old preference")

        expect(result.content).to include("forgotten")
      end

      it "includes reason when provided" do
        stub_request(:delete, "#{base_url}/v4/memories")
          .with(body: hash_including("reason" => "User changed mind"))
          .to_return(status: 200, body: { id: "mem-2", forgotten: true }.to_json)

        tool = described_class.new(api_key: api_key, container_tag: container_tag)
        result = tool.forget_memory(content: "Old fact", reason: "User changed mind")

        expect(result.content).to include("forgotten")
      end

      it "reports when memory not found" do
        stub_request(:delete, "#{base_url}/v4/memories")
          .to_return(status: 200, body: { id: "mem-3", forgotten: false }.to_json)

        tool = described_class.new(api_key: api_key, container_tag: container_tag)
        result = tool.forget_memory(content: "Non-existent memory")

        expect(result.content).to include("not found")
      end
    end
  end

  describe Supermemory::Integrations::Langchain::SupermemoryMemory do
    let(:api_key) { "test-api-key" }
    let(:container_tag) { "user-456" }
    let(:base_url) { "https://api.supermemory.ai" }

    before do
      skip "langchainrb gem not available" unless defined?(Langchain::ToolResponse)
    end

    describe "#initialize" do
      it "stores client and container_tag" do
        memory = described_class.new(api_key: api_key, container_tag: container_tag)
        expect(memory.client).to be_a(Supermemory::Client)
        expect(memory.container_tag).to eq(container_tag)
      end
    end

    describe "#context" do
      it "fetches and formats profile context" do
        stub_request(:post, "https://api.supermemory.ai/v4/profile")
          .to_return(status: 200, body: {
            profile: {
              static: ["Ruby developer", "Based in NYC"],
              dynamic: ["Working on SDK", "Learning Rust"]
            },
            searchResults: { results: [] }
          }.to_json)

        memory = described_class.new(api_key: api_key, container_tag: container_tag)
        result = memory.context

        expect(result).to include("Ruby developer")
        expect(result).to include("Based in NYC")
        expect(result).to include("Working on SDK")
        expect(result).to include("Learning Rust")
      end

      it "includes search results when query is provided" do
        stub_request(:post, "https://api.supermemory.ai/v4/profile")
          .with(body: hash_including("q" => "preferences"))
          .to_return(status: 200, body: {
            profile: { static: [], dynamic: [] },
            searchResults: {
              results: [
                { memory: "Prefers dark mode" },
                { memory: "Uses Vim" }
              ]
            }
          }.to_json)

        memory = described_class.new(api_key: api_key, container_tag: container_tag)
        result = memory.context(query: "preferences")

        expect(result).to include("Prefers dark mode")
        expect(result).to include("Uses Vim")
      end

      it "returns empty string on API error" do
        stub_request(:post, "https://api.supermemory.ai/v4/profile")
          .to_return(status: 500, body: { error: "Server error" }.to_json)

        memory = described_class.new(api_key: api_key, container_tag: container_tag)
        result = memory.context

        expect(result).to eq("")
      end
    end

    describe "#store" do
      it "stores user and assistant messages" do
        stub = stub_request(:post, "https://api.supermemory.ai/v3/documents")
               .with(body: hash_including(
                 "content" => "User: Hello\nAssistant: Hi there!",
                 "containerTag" => container_tag
               ))
               .to_return(status: 200, body: { id: "doc-1", status: "queued" }.to_json)

        memory = described_class.new(api_key: api_key, container_tag: container_tag)
        memory.store(user_message: "Hello", assistant_message: "Hi there!")

        expect(stub).to have_been_requested
      end

      it "stores only user message when assistant message is nil" do
        stub = stub_request(:post, "https://api.supermemory.ai/v3/documents")
               .with(body: hash_including(
                 "content" => "Just a note",
                 "containerTag" => container_tag
               ))
               .to_return(status: 200, body: { id: "doc-2", status: "queued" }.to_json)

        memory = described_class.new(api_key: api_key, container_tag: container_tag)
        memory.store(user_message: "Just a note")

        expect(stub).to have_been_requested
      end

      it "accepts metadata" do
        stub_request(:post, "https://api.supermemory.ai/v3/documents")
          .with(body: hash_including("metadata" => { "source" => "web" }))
          .to_return(status: 200, body: { id: "doc-3", status: "queued" }.to_json)

        memory = described_class.new(api_key: api_key, container_tag: container_tag)
        memory.store(user_message: "Test", metadata: { "source" => "web" })
      end

      it "handles errors gracefully" do
        stub_request(:post, "https://api.supermemory.ai/v3/documents")
          .to_return(status: 500, body: { error: "Server error" }.to_json)

        memory = described_class.new(api_key: api_key, container_tag: container_tag)

        expect { memory.store(user_message: "Test") }.not_to raise_error
      end
    end

    describe "#search" do
      it "searches memories with default limit" do
        stub_request(:post, "https://api.supermemory.ai/v4/search")
          .with(body: hash_including("limit" => 5))
          .to_return(status: 200, body: {
            results: [
              { id: "m1", memory: "Result 1" },
              { id: "m2", memory: "Result 2" }
            ],
            total: 2
          }.to_json)

        memory = described_class.new(api_key: api_key, container_tag: container_tag)
        results = memory.search(query: "test")

        expect(results.size).to eq(2)
        expect(results.first["memory"]).to eq("Result 1")
      end

      it "uses custom limit" do
        stub_request(:post, "https://api.supermemory.ai/v4/search")
          .with(body: hash_including("limit" => 10))
          .to_return(status: 200, body: { results: [], total: 0 }.to_json)

        memory = described_class.new(api_key: api_key, container_tag: container_tag)
        memory.search(query: "test", limit: 10)
      end

      it "returns empty array on error" do
        stub_request(:post, "https://api.supermemory.ai/v4/search")
          .to_return(status: 500, body: { error: "Server error" }.to_json)

        memory = described_class.new(api_key: api_key, container_tag: container_tag)
        results = memory.search(query: "test")

        expect(results).to eq([])
      end
    end
  end
end
