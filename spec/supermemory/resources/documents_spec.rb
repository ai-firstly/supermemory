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

  describe "#add with all optional params" do
    it "sends camelCase keys for all optional params" do
      stub = stub_request(:post, "https://api.supermemory.ai/v3/documents")
             .with(body: hash_including(
               "content" => "Hello",
               "containerTag" => "project-1",
               "customId" => "my-doc",
               "entityContext" => "user preferences",
               "metadata" => { "source" => "test" }
             ))
             .to_return(status: 200, body: { id: "d1", status: "queued" }.to_json)

      result = documents.add(
        content: "Hello",
        container_tag: "project-1",
        custom_id: "my-doc",
        entity_context: "user preferences",
        metadata: { "source" => "test" }
      )
      expect(result["id"]).to eq("d1")
      expect(stub).to have_been_requested
    end
  end

  describe "#batch_add with container_tag" do
    it "sends containerTag in the body" do
      stub = stub_request(:post, "https://api.supermemory.ai/v3/documents/batch")
             .with(body: hash_including("containerTag" => "batch-tag"))
             .to_return(status: 200, body: [{ id: "d1", status: "queued" }].to_json)

      documents.batch_add(documents: %w[doc1], container_tag: "batch-tag")
      expect(stub).to have_been_requested
    end
  end

  describe "#update with multiple fields" do
    it "updates content, container_tag and metadata" do
      stub = stub_request(:patch, "https://api.supermemory.ai/v3/documents/doc-456")
             .with(body: hash_including(
               "content" => "new content",
               "containerTag" => "new-tag",
               "metadata" => { "key" => "val" }
             ))
             .to_return(status: 200, body: { id: "doc-456", status: "queued" }.to_json)

      documents.update("doc-456", content: "new content", container_tag: "new-tag", metadata: { "key" => "val" })
      expect(stub).to have_been_requested
    end

    it "updates with custom_id" do
      stub = stub_request(:patch, "https://api.supermemory.ai/v3/documents/doc-789")
             .with(body: hash_including("customId" => "new-custom-id"))
             .to_return(status: 200, body: { id: "doc-789", status: "queued" }.to_json)

      documents.update("doc-789", custom_id: "new-custom-id")
      expect(stub).to have_been_requested
    end
  end

  describe "#list with filters and pagination" do
    it "sends filters and pagination params" do
      stub = stub_request(:post, "https://api.supermemory.ai/v3/documents/list")
             .with(body: hash_including(
               "filters" => { "AND" => [{ "key" => "source", "value" => "web" }] },
               "limit" => 10,
               "page" => 2,
               "sort" => "createdAt",
               "order" => "desc"
             ))
             .to_return(status: 200, body: {
               memories: [], pagination: { currentPage: 2, totalPages: 5, totalItems: 50 }
             }.to_json)

      result = documents.list(
        filters: { "AND" => [{ "key" => "source", "value" => "web" }] },
        limit: 10, page: 2, sort: "createdAt", order: "desc"
      )
      expect(result["pagination"]["currentPage"]).to eq(2)
      expect(stub).to have_been_requested
    end

    it "sends includeContent when true" do
      stub = stub_request(:post, "https://api.supermemory.ai/v3/documents/list")
             .with(body: hash_including("includeContent" => true))
             .to_return(status: 200, body: { memories: [], pagination: {} }.to_json)

      documents.list(include_content: true)
      expect(stub).to have_been_requested
    end
  end

  describe "#delete_bulk with container_tags" do
    it "sends containerTags instead of ids" do
      stub = stub_request(:delete, "https://api.supermemory.ai/v3/documents/bulk")
             .with(body: hash_including("containerTags" => %w[tag-a tag-b]))
             .to_return(status: 200, body: { deletedCount: 10, success: true }.to_json)

      result = documents.delete_bulk(container_tags: %w[tag-a tag-b])
      expect(result["deletedCount"]).to eq(10)
      expect(stub).to have_been_requested
    end
  end

  describe "#upload_file" do
    it "calls multipart_post" do
      file_part = double("file_part")
      expect(client).to receive(:multipart_post)
        .with("/v3/documents/file", hash_including(file: file_part))
        .and_return({ "id" => "file-1", "status" => "queued" })

      result = documents.upload_file(file: file_part)
      expect(result["id"]).to eq("file-1")
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
