# frozen_string_literal: true

RSpec.describe Supermemory do
  describe ".new" do
    it "creates a Client instance" do
      client = described_class.new(api_key: "test-key")
      expect(client).to be_a(Supermemory::Client)
    end
  end
end
