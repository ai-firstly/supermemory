# frozen_string_literal: true

RSpec.describe Supermemory::Resources::Memories do
  let(:client) { Supermemory::Client.new(api_key: "test-key") }
  let(:memories) { client.memories }

  describe "#forget" do
    it "soft-deletes a memory" do
      stub_request(:delete, "https://api.supermemory.ai/v4/memories")
        .with(body: hash_including("containerTag" => "user-1", "id" => "mem-1"))
        .to_return(status: 200, body: { id: "mem-1", forgotten: true }.to_json)

      result = memories.forget(container_tag: "user-1", id: "mem-1")
      expect(result["forgotten"]).to be true
    end
  end

  describe "#update_memory" do
    it "creates a new version" do
      stub_request(:patch, "https://api.supermemory.ai/v4/memories")
        .with(body: hash_including("containerTag" => "user-1", "newContent" => "updated fact"))
        .to_return(status: 200, body: {
          id: "mem-2", memory: "updated fact", version: 2,
          parentMemoryId: "mem-1", rootMemoryId: "mem-1"
        }.to_json)

      result = memories.update_memory(
        container_tag: "user-1",
        new_content: "updated fact",
        id: "mem-1"
      )
      expect(result["version"]).to eq(2)
    end
  end

  describe "#forget with content" do
    it "sends content instead of id" do
      stub = stub_request(:delete, "https://api.supermemory.ai/v4/memories")
             .with(body: hash_including("containerTag" => "user-1", "content" => "old fact"))
             .to_return(status: 200, body: { id: "mem-3", forgotten: true }.to_json)

      result = memories.forget(container_tag: "user-1", content: "old fact")
      expect(result["forgotten"]).to be true
      expect(stub).to have_been_requested
    end
  end

  describe "#forget with reason" do
    it "sends reason in the body" do
      stub = stub_request(:delete, "https://api.supermemory.ai/v4/memories")
             .with(body: hash_including(
               "containerTag" => "user-1",
               "id" => "mem-1",
               "reason" => "no longer relevant"
             ))
             .to_return(status: 200, body: { id: "mem-1", forgotten: true }.to_json)

      memories.forget(container_tag: "user-1", id: "mem-1", reason: "no longer relevant")
      expect(stub).to have_been_requested
    end
  end

  describe "#update_memory with content" do
    it "sends content instead of id for lookup" do
      stub = stub_request(:patch, "https://api.supermemory.ai/v4/memories")
             .with(body: hash_including(
               "containerTag" => "user-1",
               "newContent" => "corrected fact",
               "content" => "original fact"
             ))
             .to_return(status: 200, body: {
               id: "mem-4", memory: "corrected fact", version: 1
             }.to_json)

      result = memories.update_memory(
        container_tag: "user-1",
        new_content: "corrected fact",
        content: "original fact"
      )
      expect(result["memory"]).to eq("corrected fact")
      expect(stub).to have_been_requested
    end
  end

  describe "#update_memory with metadata" do
    it "sends metadata in the body" do
      stub = stub_request(:patch, "https://api.supermemory.ai/v4/memories")
             .with(body: hash_including(
               "containerTag" => "user-1",
               "newContent" => "updated",
               "id" => "mem-1",
               "metadata" => { "source" => "chat" }
             ))
             .to_return(status: 200, body: {
               id: "mem-5", memory: "updated", version: 2
             }.to_json)

      result = memories.update_memory(
        container_tag: "user-1",
        new_content: "updated",
        id: "mem-1",
        metadata: { "source" => "chat" }
      )
      expect(result["version"]).to eq(2)
      expect(stub).to have_been_requested
    end
  end
end
