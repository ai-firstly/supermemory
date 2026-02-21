# frozen_string_literal: true

RSpec.describe Supermemory::Resources::Connections do
  let(:client) { Supermemory::Client.new(api_key: "test-key") }
  let(:connections) { client.connections }

  describe "#create" do
    it "creates a connection" do
      stub_request(:post, "https://api.supermemory.ai/v3/connections/github")
        .to_return(status: 200, body: {
          id: "conn-1", authLink: "https://github.com/login/oauth", expiresIn: "10m"
        }.to_json)

      result = connections.create("github", redirect_url: "https://myapp.com/callback")
      expect(result["authLink"]).to include("github.com")
    end
  end

  describe "#list" do
    it "lists connections" do
      stub_request(:post, "https://api.supermemory.ai/v3/connections/list")
        .to_return(status: 200, body: [{ id: "conn-1", provider: "github" }].to_json)

      result = connections.list
      expect(result.first["provider"]).to eq("github")
    end
  end

  describe "#get_by_id" do
    it "retrieves a connection" do
      stub_request(:get, "https://api.supermemory.ai/v3/connections/conn-1")
        .to_return(status: 200, body: { id: "conn-1", provider: "github", status: "active" }.to_json)

      result = connections.get_by_id("conn-1")
      expect(result["status"]).to eq("active")
    end
  end

  describe "#delete_by_id" do
    it "deletes a connection" do
      stub_request(:delete, "https://api.supermemory.ai/v3/connections/conn-1")
        .to_return(status: 200, body: { success: true }.to_json)

      result = connections.delete_by_id("conn-1")
      expect(result["success"]).to be true
    end
  end

  describe "#import" do
    it "triggers import" do
      stub_request(:post, "https://api.supermemory.ai/v3/connections/github/import")
        .to_return(status: 200, body: "Import started".to_json)

      result = connections.import("github")
      expect(result).to eq("Import started")
    end
  end

  describe "#list_documents" do
    it "lists connection documents" do
      stub_request(:post, "https://api.supermemory.ai/v3/connections/github/documents")
        .to_return(status: 200, body: [{ id: "doc-1", title: "README.md" }].to_json)

      result = connections.list_documents("github")
      expect(result.first["title"]).to eq("README.md")
    end
  end

  describe "#configure" do
    it "configures a connection" do
      stub_request(:post, "https://api.supermemory.ai/v3/connections/conn-1/configure")
        .with(body: hash_including("resources"))
        .to_return(status: 200, body: { message: "Configured", success: true }.to_json)

      result = connections.configure("conn-1", resources: [{ id: "repo-1", type: "repository" }])
      expect(result["success"]).to be true
    end
  end

  describe "#resources" do
    it "lists connection resources" do
      stub_request(:get, "https://api.supermemory.ai/v3/connections/conn-1/resources")
        .to_return(status: 200, body: { resources: [{ id: "r1" }], total_count: 1 }.to_json)

      result = connections.resources("conn-1")
      expect(result["total_count"]).to eq(1)
    end
  end
end
