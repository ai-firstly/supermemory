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
end
