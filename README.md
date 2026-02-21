# Supermemory Ruby SDK

Ruby SDK for [Supermemory](https://supermemory.ai) — Memory API for the AI era.

Add persistent memory to AI applications with document management, semantic search, user profiling, and integrations with popular Ruby AI frameworks.

[![Gem Version](https://badge.fury.io/rb/supermemory.svg)](https://rubygems.org/gems/supermemory)
[![CI](https://github.com/ai-firstly/supermemory/actions/workflows/ci.yml/badge.svg)](https://github.com/ai-firstly/supermemory/actions/workflows/ci.yml)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.0-ruby.svg)](https://www.ruby-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

## Installation

Add to your Gemfile:

```ruby
gem "supermemory"
```

Or install directly:

```bash
gem install supermemory
```

## Quick Start

```ruby
require "supermemory"

client = Supermemory::Client.new(api_key: ENV["SUPERMEMORY_API_KEY"])

# Add a document
result = client.add(content: "The user prefers dark mode and uses Ruby daily.")
puts result["id"]

# Search memories
results = client.search.memories(q: "user preferences", container_tag: "user-123")
results["results"].each { |r| puts r["memory"] }

# Get user profile
profile = client.profile(container_tag: "user-123")
puts profile["profile"]["static"]   # Long-term facts
puts profile["profile"]["dynamic"]  # Recent context
```

## Configuration

### Global configuration

```ruby
Supermemory.configure do |config|
  config.api_key = ENV["SUPERMEMORY_API_KEY"]
  config.base_url = "https://api.supermemory.ai"  # default
  config.timeout = 60                              # seconds, default
  config.max_retries = 2                           # default
end

client = Supermemory::Client.new
```

### Per-client configuration

```ruby
client = Supermemory::Client.new(
  api_key: "sk-...",
  base_url: "https://custom-endpoint.com",
  timeout: 30,
  max_retries: 3
)
```

### Environment variables

| Variable | Description |
|----------|-------------|
| `SUPERMEMORY_API_KEY` | Default API key |
| `SUPERMEMORY_BASE_URL` | Default base URL |

## Core API

### Documents

```ruby
# Add a document
client.documents.add(
  content: "User prefers functional programming patterns",
  container_tag: "user-123",
  custom_id: "pref-001",
  metadata: { topic: "preferences", source: "chat" },
  entity_context: "This is a user preference about coding style"
)

# Batch add
client.documents.batch_add(
  documents: [
    { content: "Fact one", container_tag: "user-123" },
    { content: "Fact two", container_tag: "user-123" }
  ]
)
# Or with plain strings:
client.documents.batch_add(
  documents: ["Fact one", "Fact two"],
  container_tag: "user-123"
)

# Get, update, delete
doc = client.documents.get("doc-id")
client.documents.update("doc-id", content: "Updated content")
client.documents.delete("doc-id")

# List with filters
client.documents.list(
  filters: {
    "AND" => [
      { key: "topic", value: "preferences" },
      { key: "source", value: "chat" }
    ]
  },
  limit: 20,
  sort: "createdAt",
  order: "desc"
)

# Bulk delete
client.documents.delete_bulk(ids: ["id1", "id2", "id3"])

# List processing documents
client.documents.list_processing

# Upload a file
file = Faraday::Multipart::FilePart.new("/path/to/doc.pdf", "application/pdf")
client.documents.upload_file(file: file, container_tag: "user-123")
```

### Search

```ruby
# Document search (v3 - chunk-level)
results = client.search.documents(
  q: "async programming",
  limit: 10,
  rerank: true,
  include_summary: true,
  filters: { "AND" => [{ key: "topic", value: "python" }] }
)

results["results"].each do |r|
  puts "#{r["title"]} (score: #{r["score"]})"
  r["chunks"].each { |c| puts "  #{c["content"]}" if c["isRelevant"] }
end

# Memory search (v4 - low latency, conversational)
results = client.search.memories(
  q: "user preferences",
  container_tag: "user-123",
  search_mode: "hybrid",  # "memories", "hybrid", or "documents"
  limit: 5,
  threshold: 0.5
)

results["results"].each do |r|
  puts r["memory"] || r["chunk"]
end
```

### Memories

```ruby
# Forget a memory
client.memories.forget(container_tag: "user-123", id: "mem-id")
# Or by content:
client.memories.forget(
  container_tag: "user-123",
  content: "User prefers dark mode",
  reason: "User updated preference"
)

# Update a memory (creates new version)
client.memories.update_memory(
  container_tag: "user-123",
  id: "mem-id",
  new_content: "User prefers light mode now"
)
```

### User Profile

```ruby
result = client.profile(container_tag: "user-123", q: "coding preferences")

puts result["profile"]["static"]    # ["Prefers Ruby", "10 years experience"]
puts result["profile"]["dynamic"]   # ["Working on SDK", "Learning Rust"]

# Search results included when q is provided
if result["searchResults"]
  result["searchResults"]["results"].each { |r| puts r["memory"] }
end
```

### Settings

```ruby
settings = client.settings.get
client.settings.update(chunk_size: 1500, should_llm_filter: true)
```

### Connections

```ruby
# Create OAuth connection
conn = client.connections.create("github",
  redirect_url: "https://myapp.com/callback",
  document_limit: 100
)
puts conn["authLink"]  # Redirect user here

# List connections
client.connections.list

# Import/sync
client.connections.import("github")

# List documents from a connection
client.connections.list_documents("github")
```

## Error Handling

```ruby
begin
  client.add(content: "test")
rescue Supermemory::AuthenticationError => e
  puts "Invalid API key: #{e.message}"
rescue Supermemory::RateLimitError => e
  puts "Rate limited: #{e.message}"
rescue Supermemory::NotFoundError => e
  puts "Not found: #{e.message}"
rescue Supermemory::InternalServerError => e
  puts "Server error (retries exhausted): #{e.message}"
rescue Supermemory::APIConnectionError => e
  puts "Connection failed: #{e.message}"
rescue Supermemory::APITimeoutError => e
  puts "Request timed out: #{e.message}"
end
```

Automatic retries with exponential backoff are applied for status codes 408, 409, 429, and 5xx.

---

## Integrations

### ruby-openai Integration

Works with [ruby-openai](https://github.com/alexrudall/ruby-openai).

#### Approach 1: `with_supermemory` Wrapper (Automatic)

Wraps your OpenAI client to auto-inject memories into system prompts:

```ruby
require "supermemory/integrations/openai"
require "openai"

openai = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

# Wrap with Supermemory — memories are automatically included
client = Supermemory::Integrations::OpenAI.with_supermemory(openai, "user-123",
  mode: "full",          # "profile", "query", or "full"
  add_memory: "always"   # "always" or "never"
)

# Use exactly like a normal OpenAI client
response = client.chat(parameters: {
  model: "gpt-4o",
  messages: [
    { role: "system", content: "You are a helpful assistant." },
    { role: "user", content: "What's my favorite language?" }
  ]
})
puts response.dig("choices", 0, "message", "content")
```

**Modes:**

| Mode | Description |
|------|-------------|
| `profile` | Injects user profile (static + dynamic facts) |
| `query` | Searches memories based on user message |
| `full` | Both profile and search (best for chatbots) |

#### Approach 2: Function Calling Tools (Explicit)

The model decides when to search or add memories:

```ruby
require "supermemory/integrations/openai"
require "openai"

openai = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
tools = Supermemory::Integrations::OpenAI::SupermemoryTools.new(
  api_key: ENV["SUPERMEMORY_API_KEY"],
  config: { container_tag: "user-123" }
)

response = openai.chat(parameters: {
  model: "gpt-4o",
  messages: [
    { role: "system", content: "You are a helpful assistant with memory." },
    { role: "user", content: "Remember that I prefer tea over coffee" }
  ],
  tools: tools.get_tool_definitions
})

# Handle tool calls
message = response.dig("choices", 0, "message")
if message["tool_calls"]
  tool_results = Supermemory::Integrations::OpenAI.execute_memory_tool_calls(
    api_key: ENV["SUPERMEMORY_API_KEY"],
    tool_calls: message["tool_calls"],
    config: { container_tag: "user-123" }
  )

  # Feed results back for final response
  messages = [
    { role: "system", content: "You are a helpful assistant with memory." },
    { role: "user", content: "Remember that I prefer tea over coffee" },
    message,
    *tool_results
  ]

  final = openai.chat(parameters: { model: "gpt-4o", messages: messages })
  puts final.dig("choices", 0, "message", "content")
end
```

### graph-agent Integration

Works with [graph-agent](https://github.com/ai-firstly/graph-agent).

#### Quick Start with `build_memory_graph`

```ruby
require "supermemory/integrations/graph_agent"
require "graph_agent"

# Define your LLM node
llm_node = ->(state, _config) {
  context = state[:memory_context]
  # Call your LLM here with memory context
  response_text = "Based on what I know: #{context.empty? ? "nothing yet" : context}"
  { messages: [{ role: "assistant", content: response_text }] }
}

# Build a complete memory-augmented graph
app = Supermemory::Integrations::GraphAgent.build_memory_graph(
  api_key: ENV["SUPERMEMORY_API_KEY"],
  llm_node: llm_node
)

# Run it
result = app.invoke(
  { messages: [{ role: "user", content: "What are my preferences?" }], user_id: "user-123" }
)
puts result[:messages].last[:content]
```

#### Custom Graph with Memory Nodes

```ruby
require "supermemory/integrations/graph_agent"
require "graph_agent"

nodes = Supermemory::Integrations::GraphAgent::Nodes.new(
  api_key: ENV["SUPERMEMORY_API_KEY"]
)

schema = Supermemory::Integrations::GraphAgent.memory_schema(
  extra_fields: { intent: { type: String, default: "" } }
)

graph = GraphAgent::Graph::StateGraph.new(schema)

# Add memory nodes
graph.add_node("recall", nodes.method(:recall_memories))
graph.add_node("store", nodes.method(:store_memory))

# Add your custom nodes
graph.add_node("classify") do |state|
  { intent: state[:messages].last[:content].match?(/remember|save/i) ? "store" : "query" }
end

graph.add_node("respond") do |state|
  context = state[:memory_context]
  { messages: [{ role: "assistant", content: "Response with context: #{context}" }] }
end

# Wire edges
graph.add_edge(GraphAgent::START, "recall")
graph.add_edge("recall", "classify")
graph.add_conditional_edges("classify", ->(s) { s[:intent] }, {
  "store" => "store",
  "query" => "respond"
})
graph.add_edge("respond", "store")
graph.add_edge("store", GraphAgent::END_NODE)

app = graph.compile
result = app.invoke(
  { messages: [{ role: "user", content: "Remember I like Ruby" }], user_id: "user-123" }
)
```

#### Available Node Functions

| Node | Purpose | State Input | State Output |
|------|---------|-------------|--------------|
| `recall_memories` | Fetch profile + relevant memories | `:messages`, `:user_id` | `:memories`, `:memory_context` |
| `store_memory` | Store latest conversation exchange | `:messages`, `:user_id` | (none) |
| `search_memories` | Search with specific query | `:query` or `:messages`, `:user_id` | `:memories` |
| `add_memory` | Store specific content | `:memory_content`, `:user_id` | (none) |

### langchainrb Integration

Works with [langchainrb](https://github.com/patterns-ai-core/langchainrb).

#### As a Tool with Langchain::Assistant

```ruby
require "supermemory/integrations/langchain"
require "langchain"

llm = Langchain::LLM::OpenAI.new(api_key: ENV["OPENAI_API_KEY"])
memory_tool = Supermemory::Integrations::Langchain::SupermemoryTool.new(
  api_key: ENV["SUPERMEMORY_API_KEY"],
  container_tag: "user-123"
)

assistant = Langchain::Assistant.new(
  llm: llm,
  tools: [memory_tool],
  instructions: "You are a helpful assistant with persistent memory. " \
                "Use memory tools to remember and recall information."
)

# The assistant will automatically use search_memory/add_memory as needed
assistant.add_message_and_run!(content: "Remember that my favorite language is Ruby")
assistant.add_message_and_run!(content: "What's my favorite programming language?")

puts assistant.messages.last.content
```

#### Available Tool Functions

| Function | Description |
|----------|-------------|
| `search_memory` | Search memories by query (supports memories/hybrid/documents modes) |
| `add_memory` | Save information to long-term memory |
| `get_profile` | Get user profile with optional search |
| `forget_memory` | Remove specific memory by content |

#### Manual Memory Management

For non-tool-based memory injection:

```ruby
require "supermemory/integrations/langchain"

memory = Supermemory::Integrations::Langchain::SupermemoryMemory.new(
  api_key: ENV["SUPERMEMORY_API_KEY"],
  container_tag: "user-123"
)

# Get context for system prompt
context = memory.context(query: "user preferences")

# Use with any LLM call
llm = Langchain::LLM::OpenAI.new(api_key: ENV["OPENAI_API_KEY"])
response = llm.chat(messages: [
  { role: "system", content: "You are a helpful assistant.\n\n#{context}" },
  { role: "user", content: "What are my preferences?" }
])

# Store the exchange
memory.store(
  user_message: "What are my preferences?",
  assistant_message: response.chat_completion
)

# Direct search
results = memory.search(query: "coding preferences", limit: 5)
```

## Development

```bash
git clone https://github.com/ai-firstly/supermemory.git
cd supermemory
bundle install
bundle exec rspec
```

## License

MIT License. See [LICENSE](LICENSE).
