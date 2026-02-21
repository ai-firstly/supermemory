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
end
