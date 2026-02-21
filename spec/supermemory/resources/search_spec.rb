# frozen_string_literal: true

RSpec.describe Supermemory::Resources::Search do
  let(:client) { Supermemory::Client.new(api_key: "test-key") }
  let(:search) { client.search }

  describe "#documents" do
    it "searches documents" do
      stub_request(:post, "https://api.supermemory.ai/v3/search")
        .with(body: hash_including("q" => "ruby programming"))
        .to_return(status: 200, body: {
          results: [{ documentId: "d1", score: 0.95, chunks: [] }],
          timing: 42,
          total: 1
        }.to_json)

      result = search.documents(q: "ruby programming")
      expect(result["total"]).to eq(1)
      expect(result["results"].first["documentId"]).to eq("d1")
    end
  end

  describe "#execute" do
    it "is an alias for documents" do
      stub_request(:post, "https://api.supermemory.ai/v3/search")
        .to_return(status: 200, body: { results: [], timing: 10, total: 0 }.to_json)

      result = search.execute(q: "test")
      expect(result["results"]).to eq([])
    end
  end

  describe "#memories" do
    it "searches memories via v4 API" do
      stub_request(:post, "https://api.supermemory.ai/v4/search")
        .with(body: hash_including("q" => "preferences", "containerTag" => "user-1"))
        .to_return(status: 200, body: {
          results: [{ id: "m1", memory: "Likes Ruby", similarity: 0.9 }],
          timing: 15,
          total: 1
        }.to_json)

      result = search.memories(q: "preferences", container_tag: "user-1")
      expect(result["results"].first["memory"]).to eq("Likes Ruby")
    end
  end

  describe "#documents with optional params" do
    it "sends limit, rerank, include_summary and filters" do
      stub = stub_request(:post, "https://api.supermemory.ai/v3/search")
             .with(body: hash_including(
               "q" => "test query",
               "limit" => 5,
               "rerank" => true,
               "includeSummary" => true,
               "filters" => { "AND" => [{ "key" => "type", "value" => "doc" }] }
             ))
             .to_return(status: 200, body: { results: [], timing: 20, total: 0 }.to_json)

      search.documents(
        q: "test query", limit: 5, rerank: true,
        include_summary: true,
        filters: { "AND" => [{ "key" => "type", "value" => "doc" }] }
      )
      expect(stub).to have_been_requested
    end

    it "sends onlyMatchingChunks, rewriteQuery, chunkThreshold and docId" do
      stub = stub_request(:post, "https://api.supermemory.ai/v3/search")
             .with(body: hash_including(
               "q" => "deep search",
               "onlyMatchingChunks" => true,
               "rewriteQuery" => true,
               "chunkThreshold" => 0.8,
               "docId" => "doc-99"
             ))
             .to_return(status: 200, body: { results: [], timing: 30, total: 0 }.to_json)

      search.documents(
        q: "deep search", only_matching_chunks: true,
        rewrite_query: true, chunk_threshold: 0.8, doc_id: "doc-99"
      )
      expect(stub).to have_been_requested
    end
  end

  describe "#memories with search_mode and threshold" do
    it "sends searchMode and threshold" do
      stub = stub_request(:post, "https://api.supermemory.ai/v4/search")
             .with(body: hash_including(
               "q" => "facts",
               "searchMode" => "hybrid",
               "threshold" => 0.7
             ))
             .to_return(status: 200, body: { results: [], timing: 10, total: 0 }.to_json)

      search.memories(q: "facts", search_mode: "hybrid", threshold: 0.7)
      expect(stub).to have_been_requested
    end
  end

  describe "#memories minimal" do
    it "sends only q" do
      stub = stub_request(:post, "https://api.supermemory.ai/v4/search")
             .with(body: { "q" => "hello" })
             .to_return(status: 200, body: { results: [], timing: 5, total: 0 }.to_json)

      result = search.memories(q: "hello")
      expect(result["total"]).to eq(0)
      expect(stub).to have_been_requested
    end
  end
end
