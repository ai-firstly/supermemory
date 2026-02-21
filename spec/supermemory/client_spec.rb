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

    it "memoizes resource objects" do
      expect(client.documents).to be(client.documents)
      expect(client.search).to be(client.search)
      expect(client.memories).to be(client.memories)
      expect(client.settings).to be(client.settings)
      expect(client.connections).to be(client.connections)
    end
  end

  describe "#initialize (additional)" do
    it "accepts custom timeout" do
      client = described_class.new(api_key: "key", timeout: 120)
      expect(client.timeout).to eq(120)
    end

    it "accepts custom max_retries" do
      client = described_class.new(api_key: "key", max_retries: 5)
      expect(client.max_retries).to eq(5)
    end

    it "accepts extra_headers" do
      stub = stub_request(:get, "https://api.supermemory.ai/v3/settings")
             .with(headers: { "X-Custom" => "value" })
             .to_return(status: 200, body: { chunkSize: 1000 }.to_json)

      client = described_class.new(api_key: "key", extra_headers: { "X-Custom" => "value" })
      client.settings.get
      expect(stub).to have_been_requested
    end
  end

  describe "#profile (additional)" do
    it "passes q parameter" do
      stub = stub_request(:post, "https://api.supermemory.ai/v4/profile")
             .with(body: { container_tag: "user-1", q: "ruby" }.to_json)
             .to_return(status: 200, body: { profile: {}, searchResults: [] }.to_json)

      client.profile(container_tag: "user-1", q: "ruby")
      expect(stub).to have_been_requested
    end

    it "passes threshold parameter" do
      stub = stub_request(:post, "https://api.supermemory.ai/v4/profile")
             .with(body: { container_tag: "user-1", threshold: 0.8 }.to_json)
             .to_return(status: 200, body: { profile: {}, searchResults: [] }.to_json)

      client.profile(container_tag: "user-1", threshold: 0.8)
      expect(stub).to have_been_requested
    end

    it "passes both q and threshold parameters" do
      stub = stub_request(:post, "https://api.supermemory.ai/v4/profile")
             .with(body: { container_tag: "user-1", q: "ruby", threshold: 0.5 }.to_json)
             .to_return(status: 200, body: { profile: {}, searchResults: [] }.to_json)

      client.profile(container_tag: "user-1", q: "ruby", threshold: 0.5)
      expect(stub).to have_been_requested
    end
  end

  describe "#multipart_post" do
    it "exists as a public method" do
      expect(client).to respond_to(:multipart_post)
    end
  end

  describe "retry logic (additional)" do
    before { allow(client).to receive(:sleep) }

    it "raises after exhausting max_retries" do
      client = described_class.new(api_key: "test-key", max_retries: 2)
      allow(client).to receive(:sleep)

      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 500, body: { error: "Server error" }.to_json)

      expect { client.settings.get }.to raise_error(Supermemory::InternalServerError)

      expect(a_request(:get, "https://api.supermemory.ai/v3/settings"))
        .to have_been_made.times(3) # 1 initial + 2 retries
    end

    it "does not retry non-retryable status codes" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 400, body: { error: "Bad request" }.to_json)

      expect { client.settings.get }.to raise_error(Supermemory::BadRequestError)

      expect(a_request(:get, "https://api.supermemory.ai/v3/settings"))
        .to have_been_made.once
    end

    it "does not retry 401 errors" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 401, body: { error: "Unauthorized" }.to_json)

      expect { client.settings.get }.to raise_error(Supermemory::AuthenticationError)

      expect(a_request(:get, "https://api.supermemory.ai/v3/settings"))
        .to have_been_made.once
    end

    it "does not retry 403 errors" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 403, body: { error: "Forbidden" }.to_json)

      expect { client.settings.get }.to raise_error(Supermemory::PermissionDeniedError)

      expect(a_request(:get, "https://api.supermemory.ai/v3/settings"))
        .to have_been_made.once
    end

    it "does not retry 404 errors" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 404, body: { error: "Not found" }.to_json)

      expect { client.settings.get }.to raise_error(Supermemory::NotFoundError)

      expect(a_request(:get, "https://api.supermemory.ai/v3/settings"))
        .to have_been_made.once
    end

    it "does not retry 422 errors" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 422, body: { error: "Unprocessable" }.to_json)

      expect { client.settings.get }.to raise_error(Supermemory::UnprocessableEntityError)

      expect(a_request(:get, "https://api.supermemory.ai/v3/settings"))
        .to have_been_made.once
    end

    it "retries on 408 errors" do
      client = described_class.new(api_key: "test-key", max_retries: 1)
      allow(client).to receive(:sleep)

      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 408, body: { error: "Timeout" }.to_json)
        .then.to_return(status: 200, body: { chunkSize: 1000 }.to_json)

      result = client.settings.get
      expect(result["chunkSize"]).to eq(1000)
      expect(a_request(:get, "https://api.supermemory.ai/v3/settings"))
        .to have_been_made.times(2)
    end

    it "retries on 429 errors" do
      client = described_class.new(api_key: "test-key", max_retries: 1)
      allow(client).to receive(:sleep)

      stub_request(:post, "https://api.supermemory.ai/v3/documents")
        .to_return(status: 429, body: { error: "Rate limited" }.to_json)
        .then.to_return(status: 200, body: { id: "doc-1" }.to_json)

      result = client.add(content: "test")
      expect(result["id"]).to eq("doc-1")
    end

    it "retries on 502 errors" do
      client = described_class.new(api_key: "test-key", max_retries: 1)
      allow(client).to receive(:sleep)

      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 502, body: { error: "Bad gateway" }.to_json)
        .then.to_return(status: 200, body: { chunkSize: 500 }.to_json)

      result = client.settings.get
      expect(result["chunkSize"]).to eq(500)
    end

    it "retries on 503 errors" do
      client = described_class.new(api_key: "test-key", max_retries: 1)
      allow(client).to receive(:sleep)

      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 503, body: { error: "Unavailable" }.to_json)
        .then.to_return(status: 200, body: { chunkSize: 500 }.to_json)

      result = client.settings.get
      expect(result["chunkSize"]).to eq(500)
    end

    it "retries on 504 errors" do
      client = described_class.new(api_key: "test-key", max_retries: 1)
      allow(client).to receive(:sleep)

      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 504, body: { error: "Gateway timeout" }.to_json)
        .then.to_return(status: 200, body: { chunkSize: 500 }.to_json)

      result = client.settings.get
      expect(result["chunkSize"]).to eq(500)
    end
  end

  describe "timeout and connection errors" do
    it "raises APITimeoutError on Faraday::TimeoutError" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_raise(Faraday::TimeoutError.new("execution expired"))

      expect { client.settings.get }.to raise_error(Supermemory::APITimeoutError, /timed out/)
    end

    it "raises APIConnectionError on Faraday::ConnectionFailed" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_raise(Faraday::ConnectionFailed.new("connection refused"))

      expect { client.settings.get }.to raise_error(Supermemory::APIConnectionError, /connection refused/)
    end
  end

  describe "response parsing" do
    it "returns nil for empty body" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 200, body: "")

      expect(client.settings.get).to be_nil
    end

    it "returns nil for nil body" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 200, body: nil)

      expect(client.settings.get).to be_nil
    end

    it "returns non-JSON body as-is" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 200, body: "plain text response")

      expect(client.settings.get).to eq("plain text response")
    end
  end

  describe "error status codes" do
    it "raises BadRequestError on 400" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 400, body: { error: "Bad request" }.to_json)

      expect { client.settings.get }.to raise_error(Supermemory::BadRequestError)
    end

    it "raises PermissionDeniedError on 403" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 403, body: { error: "Forbidden" }.to_json)

      expect { client.settings.get }.to raise_error(Supermemory::PermissionDeniedError)
    end

    it "raises ConflictError on 409" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 409, body: { error: "Conflict" }.to_json)

      expect { client.settings.get }.to raise_error(Supermemory::ConflictError)
    end

    it "raises UnprocessableEntityError on 422" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 422, body: { error: "Unprocessable" }.to_json)

      expect { client.settings.get }.to raise_error(Supermemory::UnprocessableEntityError)
    end

    it "raises InternalServerError on unknown 5xx" do
      client = described_class.new(api_key: "test-key", max_retries: 0)

      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 599, body: { error: "Unknown server error" }.to_json)

      expect { client.settings.get }.to raise_error(Supermemory::InternalServerError)
    end
  end

  describe "error message extraction" do
    it "uses 'error' key from response body" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 400, body: { error: "Something went wrong" }.to_json)

      expect { client.settings.get }.to raise_error(Supermemory::BadRequestError, "Something went wrong")
    end

    it "falls back to 'message' key when 'error' key is missing" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 400, body: { message: "Validation failed" }.to_json)

      expect { client.settings.get }.to raise_error(Supermemory::BadRequestError, "Validation failed")
    end

    it "uses body string for non-JSON error responses" do
      client = described_class.new(api_key: "test-key", max_retries: 0)

      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 500, body: "Internal Server Error")

      expect { client.settings.get }.to raise_error(Supermemory::InternalServerError, "Internal Server Error")
    end
  end
end
