# frozen_string_literal: true

RSpec.describe Supermemory::Configuration do
  describe "#initialize" do
    it "sets default base_url" do
      config = described_class.new
      expect(config.base_url).to eq("https://api.supermemory.ai")
    end

    it "sets default timeout" do
      config = described_class.new
      expect(config.timeout).to eq(60)
    end

    it "sets default max_retries" do
      config = described_class.new
      expect(config.max_retries).to eq(2)
    end

    it "sets default extra_headers" do
      config = described_class.new
      expect(config.extra_headers).to eq({})
    end
  end

  describe "Supermemory.configure" do
    it "yields configuration" do
      Supermemory.configure do |config|
        config.timeout = 120
      end
      expect(Supermemory.configuration.timeout).to eq(120)
    end

    after do
      Supermemory.configure do |config|
        config.timeout = 60
      end
    end
  end
end
