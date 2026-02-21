# frozen_string_literal: true

RSpec.describe Supermemory::Resources::Settings do
  let(:client) { Supermemory::Client.new(api_key: "test-key") }
  let(:settings) { client.settings }

  describe "#get" do
    it "retrieves settings" do
      stub_request(:get, "https://api.supermemory.ai/v3/settings")
        .to_return(status: 200, body: { chunkSize: 1000, shouldLLMFilter: false }.to_json)

      result = settings.get
      expect(result["chunkSize"]).to eq(1000)
    end
  end

  describe "#update" do
    it "updates settings with ruby-style keys" do
      stub = stub_request(:patch, "https://api.supermemory.ai/v3/settings")
             .with(body: hash_including("chunkSize" => 1500, "shouldLLMFilter" => true))
             .to_return(status: 200, body: { chunkSize: 1500, shouldLLMFilter: true }.to_json)

      result = settings.update(chunk_size: 1500, should_llm_filter: true)
      expect(result["chunkSize"]).to eq(1500)
      expect(stub).to have_been_requested
    end

    it "ignores unknown keys" do
      stub = stub_request(:patch, "https://api.supermemory.ai/v3/settings")
             .to_return(status: 200, body: {}.to_json)

      settings.update(unknown_key: "value")
      expect(stub).to have_been_requested
    end
  end
end
