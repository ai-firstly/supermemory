# frozen_string_literal: true

RSpec.describe Supermemory do
  describe "VERSION" do
    it "has a version number" do
      expect(Supermemory::VERSION).not_to be_nil
    end

    it "follows semantic versioning" do
      expect(Supermemory::VERSION).to match(/\A\d+\.\d+\.\d+/)
    end
  end
end
