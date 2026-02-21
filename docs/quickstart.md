# Quickstart

## Installation

Add to your Gemfile:

```ruby
gem "supermemory"
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install supermemory
```

## Configuration

```ruby
require "supermemory"

# Option 1: Global configuration
Supermemory.configure do |config|
  config.api_key = ENV["SUPERMEMORY_API_KEY"]
end

client = Supermemory::Client.new

# Option 2: Per-client configuration
client = Supermemory::Client.new(api_key: "sk-...")
```

## Basic Usage

### Add a document

```ruby
result = client.add(content: "The user prefers dark mode and uses Ruby daily.")
puts result["id"]  # => "doc-abc123"
```

### Search memories

```ruby
results = client.search.memories(q: "user preferences", container_tag: "user-123")
results["results"].each { |r| puts r["memory"] }
```

### Get user profile

```ruby
profile = client.profile(container_tag: "user-123")
puts profile["profile"]["static"]   # Long-term facts
puts profile["profile"]["dynamic"]  # Recent context
```

### Error handling

```ruby
begin
  client.add(content: "test")
rescue Supermemory::AuthenticationError => e
  puts "Invalid API key: #{e.message}"
rescue Supermemory::RateLimitError => e
  puts "Rate limited: #{e.message}"
rescue Supermemory::APIError => e
  puts "API error: #{e.message}"
end
```

## Next Steps

- [Configuration](configuration.md) — Advanced configuration options
- [Core API](core_api.md) — Full API reference for all resources
- [Integrations](integrations.md) — Use with OpenAI, graph-agent, or langchainrb
