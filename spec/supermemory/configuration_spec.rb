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

    it "sets api_key to nil by default" do
      config = described_class.new
      expect(config.api_key).to be_nil
    end
  end

  describe "attribute setters" do
    it "allows setting base_url" do
      config = described_class.new
      config.base_url = "https://custom.api.com"
      expect(config.base_url).to eq("https://custom.api.com")
    end

    it "allows setting api_key" do
      config = described_class.new
      config.api_key = "test-key-123"
      expect(config.api_key).to eq("test-key-123")
    end

    it "allows setting timeout" do
      config = described_class.new
      config.timeout = 30
      expect(config.timeout).to eq(30)
    end

    it "allows setting max_retries" do
      config = described_class.new
      config.max_retries = 5
      expect(config.max_retries).to eq(5)
    end

    it "allows setting extra_headers" do
      config = described_class.new
      config.extra_headers = { "X-Custom" => "value" }
      expect(config.extra_headers).to eq({ "X-Custom" => "value" })
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

  describe "Supermemory.configuration" do
    it "returns the same memoized instance" do
      config1 = Supermemory.configuration
      config2 = Supermemory.configuration
      expect(config1).to be(config2)
    end
  end
end
