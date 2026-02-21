# Integrations

Supermemory integrates with popular Ruby AI frameworks.

## OpenAI (ruby-openai)

### Automatic Memory Injection

```ruby
require "supermemory/integrations/openai"
require "openai"

openai = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

client = Supermemory::Integrations::OpenAI.with_supermemory(openai, "user-123",
  mode: "full",          # "profile", "query", or "full"
  add_memory: "always"   # "always" or "never"
)

response = client.chat(parameters: {
  model: "gpt-4o",
  messages: [
    { role: "system", content: "You are a helpful assistant." },
    { role: "user", content: "What's my favorite language?" }
  ]
})
```

**Modes:**

| Mode | Description |
|------|-------------|
| `profile` | Injects user profile (static + dynamic facts) |
| `query` | Searches memories based on user message |
| `full` | Both profile and search (best for chatbots) |

### Function Calling Tools

```ruby
require "supermemory/integrations/openai"

tools = Supermemory::Integrations::OpenAI::SupermemoryTools.new(
  api_key: ENV["SUPERMEMORY_API_KEY"],
  config: { container_tag: "user-123" }
)

# Get tool definitions for OpenAI
tool_defs = tools.get_tool_definitions

# Execute tool calls from response
tool_results = Supermemory::Integrations::OpenAI.execute_memory_tool_calls(
  api_key: ENV["SUPERMEMORY_API_KEY"],
  tool_calls: message["tool_calls"],
  config: { container_tag: "user-123" }
)
```

## graph-agent

### Quick Start

```ruby
require "supermemory/integrations/graph_agent"
require "graph_agent"

llm_node = ->(state, _config) {
  context = state[:memory_context]
  { messages: [{ role: "assistant", content: "Response: #{context}" }] }
}

app = Supermemory::Integrations::GraphAgent.build_memory_graph(
  api_key: ENV["SUPERMEMORY_API_KEY"],
  llm_node: llm_node
)

result = app.invoke(
  { messages: [{ role: "user", content: "What are my preferences?" }], user_id: "user-123" }
)
```

### Custom Graph with Memory Nodes

```ruby
nodes = Supermemory::Integrations::GraphAgent::Nodes.new(
  api_key: ENV["SUPERMEMORY_API_KEY"]
)

schema = Supermemory::Integrations::GraphAgent.memory_schema
graph = GraphAgent::Graph::StateGraph.new(schema)
graph.add_node("recall", nodes.method(:recall_memories))
graph.add_node("store", nodes.method(:store_memory))
```

### Available Node Functions

| Node | Purpose | State Input | State Output |
|------|---------|-------------|--------------|
| `recall_memories` | Fetch profile + relevant memories | `:messages`, `:user_id` | `:memories`, `:memory_context` |
| `store_memory` | Store latest conversation exchange | `:messages`, `:user_id` | (none) |
| `search_memories` | Search with specific query | `:query` or `:messages`, `:user_id` | `:memories` |
| `add_memory` | Store specific content | `:memory_content`, `:user_id` | (none) |

## langchainrb

### As a Tool with Assistant

```ruby
require "supermemory/integrations/langchain"

memory_tool = Supermemory::Integrations::Langchain::SupermemoryTool.new(
  api_key: ENV["SUPERMEMORY_API_KEY"],
  container_tag: "user-123"
)

assistant = Langchain::Assistant.new(
  llm: Langchain::LLM::OpenAI.new(api_key: ENV["OPENAI_API_KEY"]),
  tools: [memory_tool],
  instructions: "You are a helpful assistant with memory."
)
```

### Manual Memory Management

```ruby
memory = Supermemory::Integrations::Langchain::SupermemoryMemory.new(
  api_key: ENV["SUPERMEMORY_API_KEY"],
  container_tag: "user-123"
)

context = memory.context(query: "user preferences")
memory.store(user_message: "I like Ruby", assistant_message: "Noted!")
results = memory.search(query: "coding preferences", limit: 5)
```

### Available Tool Functions

| Function | Description |
|----------|-------------|
| `search_memory` | Search memories (supports memories/hybrid/documents modes) |
| `add_memory` | Save information to long-term memory |
| `get_profile` | Get user profile with optional search |
| `forget_memory` | Remove specific memory by content |
