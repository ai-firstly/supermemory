# frozen_string_literal: true

require_relative "lib/supermemory/version"

Gem::Specification.new do |spec|
  spec.name = "supermemory"
  spec.version = Supermemory::VERSION
  spec.authors = ["Supermemory"]
  spec.email = ["support@supermemory.ai"]

  spec.summary = "Ruby SDK for the Supermemory API - Memory API for the AI era"
  spec.description = "Official Ruby SDK for Supermemory. Add persistent memory to AI applications " \
                     "with document management, semantic search, user profiling, and integrations " \
                     "with ruby-openai, graph-agent, and langchainrb."
  spec.homepage = "https://github.com/ai-firstly/supermemory"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://supermemory.ai/docs"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", ">= 1.0", "< 3.0"
  spec.add_dependency "faraday-multipart", ">= 1.0", "< 2.0"

  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
