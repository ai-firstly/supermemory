# frozen_string_literal: true

RSpec.describe Supermemory::Client do
  let(:client) { described_class.new(api_key: "test-key") }

  describe "#initialize" do
    it "accepts an api_key" do
      client = described_class.new(api_key: "my-key")
      expect(client.api_key).to eq("my-key")
    end

    it "raises without an api_key" do
      Supermemory.configure { |c| c.api_key = nil }
      expect { described_class.new(api_key: nil) }.to raise_error(Supermemory::Error)
    end

    it "uses default base_url" do
      expect(client.base_url).to eq("https://api.supermemory.ai")
    end

    it "accepts custom base_url" do
      client = described_class.new(api_key: "key", base_url: "https://custom.api.com")
      expect(client.base_url).to eq("https://custom.api.com")
    end
  end

  describe "#add" do
    it "posts to /v3/documents" do
      stub = stub_request(:post, "https://api.supermemory.ai/v3/documents")
             .with(
               body: { content: "hello world" }.to_json,
               headers: { "Authorization" => "Bearer test-key", "Content-Type" => "application/json" }
             )
             .to_return(status: 200, body: { id: "doc-123", status: "queued" }.to_json)

      result = client.add(content: "hello world")
      expect(result).to eq({ "id" => "doc-123", "status" => "queued" })
      expect(stub).to have_been_requested
    end

    it "passes container_tag and metadata" do
      stub = stub_request(:post, "https://api.supermemory.ai/v3/documents")
             .with(body: hash_including("content" => "test", "containerTag" => "user-1"))
             .to_return(status: 200, body: { id: "doc-1", status: "queued" }.to_json)

      client.add(content: "test", container_tag: "user-1")
      expect(stub).to have_been_requested
    end
  end

  describe "#profile" do
    it "posts to /v4/profile" do
      stub_request(:post, "https://api.supermemory.ai/v4/profile")
        .with(body: { container_tag: "user-1" }.to_json)
        .to_return(status: 200, body: {
          profile: { static: ["likes Ruby"], dynamic: ["working on SDK"] },
          searchResults: nil
        }.to_json)

      result = client.profile(container_tag: "user-1")
      expect(result["profile"]["static"]).to include("likes Ruby")
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 401, body: { error: "Unauthorized" }.to_json)

      expect { client.settings.get }.to raise_error(Supermemory::AuthenticationError)
    end

    it "raises RateLimitError on 429" do
      stub_request(:post, "https://api.supermemory.ai/v3/documents")
        .to_return(status: 429, body: { error: "Too many requests" }.to_json)

      expect { client.add(content: "test") }.to raise_error(Supermemory::RateLimitError)
    end

    it "raises NotFoundError on 404" do
      stub_request(:get, "https://api.supermemory.ai/v3/documents/missing")
        .to_return(status: 404, body: { error: "Not found" }.to_json)

      expect { client.documents.get("missing") }.to raise_error(Supermemory::NotFoundError)
    end
  end

  describe "retry logic" do
    it "retries on 500 errors" do
      stub = stub_request(:get, "https://api.supermemory.ai/v3/settings")
             .to_return(status: 500, body: { error: "Server error" }.to_json)
             .then.to_return(status: 200, body: { chunkSize: 1000 }.to_json)

      client = described_class.new(api_key: "test-key", max_retries: 2)
      result = client.settings.get
      expect(result["chunkSize"]).to eq(1000)
      expect(stub).to have_been_requested.times(2)
    end
  end

  describe "resource accessors" do
    it "returns Documents resource" do
      expect(client.documents).to be_a(Supermemory::Resources::Documents)
    end

    it "returns Search resource" do
      expect(client.search).to be_a(Supermemory::Resources::Search)
    end

    it "returns Memories resource" do
      expect(client.memories).to be_a(Supermemory::Resources::Memories)
    end

    it "returns Settings resource" do
      expect(client.settings).to be_a(Supermemory::Resources::Settings)
    end

    it "returns Connections resource" do
      expect(client.connections).to be_a(Supermemory::Resources::Connections)
    end
  end
end
