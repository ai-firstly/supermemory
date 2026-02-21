# frozen_string_literal: true

RSpec.describe Supermemory::Resources::Documents do
  let(:client) { Supermemory::Client.new(api_key: "test-key") }
  let(:documents) { client.documents }

  describe "#add" do
    it "creates a document" do
      stub_request(:post, "https://api.supermemory.ai/v3/documents")
        .with(body: hash_including("content" => "Hello"))
        .to_return(status: 200, body: { id: "d1", status: "queued" }.to_json)

      result = documents.add(content: "Hello")
      expect(result["id"]).to eq("d1")
    end
  end

  describe "#batch_add" do
    it "creates multiple documents" do
      stub_request(:post, "https://api.supermemory.ai/v3/documents/batch")
        .to_return(status: 200, body: [{ id: "d1", status: "queued" }, { id: "d2", status: "queued" }].to_json)

      result = documents.batch_add(documents: %w[doc1 doc2])
      expect(result.size).to eq(2)
    end
  end

  describe "#get" do
    it "retrieves a document" do
      stub_request(:get, "https://api.supermemory.ai/v3/documents/doc-123")
        .to_return(status: 200, body: { id: "doc-123", status: "done", title: "Test" }.to_json)

      result = documents.get("doc-123")
      expect(result["title"]).to eq("Test")
    end
  end

  describe "#update" do
    it "updates a document" do
      stub_request(:patch, "https://api.supermemory.ai/v3/documents/doc-123")
        .with(body: hash_including("content" => "updated"))
        .to_return(status: 200, body: { id: "doc-123", status: "queued" }.to_json)

      result = documents.update("doc-123", content: "updated")
      expect(result["id"]).to eq("doc-123")
    end
  end

  describe "#delete" do
    it "deletes a document" do
      stub_request(:delete, "https://api.supermemory.ai/v3/documents/doc-123")
        .to_return(status: 200, body: "")

      expect(documents.delete("doc-123")).to be_nil
    end
  end

  describe "#list" do
    it "lists documents" do
      stub_request(:post, "https://api.supermemory.ai/v3/documents/list")
        .to_return(status: 200, body: {
          memories: [{ id: "d1" }, { id: "d2" }],
          pagination: { currentPage: 1, totalPages: 1, totalItems: 2 }
        }.to_json)

      result = documents.list
      expect(result["memories"].size).to eq(2)
    end
  end

  describe "#delete_bulk" do
    it "bulk deletes documents" do
      stub_request(:delete, "https://api.supermemory.ai/v3/documents/bulk")
        .to_return(status: 200, body: { deletedCount: 3, success: true }.to_json)

      result = documents.delete_bulk(ids: %w[d1 d2 d3])
      expect(result["deletedCount"]).to eq(3)
    end
  end

  describe "#list_processing" do
    it "lists processing documents" do
      stub_request(:get, "https://api.supermemory.ai/v3/documents/processing")
        .to_return(status: 200, body: { documents: [], totalCount: 0 }.to_json)

      result = documents.list_processing
      expect(result["totalCount"]).to eq(0)
    end
  end
end
