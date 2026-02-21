# Core API

## Documents

### Add a Document

```ruby
client.documents.add(
  content: "User prefers functional programming patterns",
  container_tag: "user-123",
  custom_id: "pref-001",
  metadata: { topic: "preferences", source: "chat" },
  entity_context: "This is a user preference about coding style"
)
```

### Batch Add

```ruby
# With document objects
client.documents.batch_add(
  documents: [
    { content: "Fact one", container_tag: "user-123" },
    { content: "Fact two", container_tag: "user-123" }
  ]
)

# With plain strings
client.documents.batch_add(
  documents: ["Fact one", "Fact two"],
  container_tag: "user-123"
)
```

### Get, Update, Delete

```ruby
doc = client.documents.get("doc-id")
client.documents.update("doc-id", content: "Updated content")
client.documents.delete("doc-id")
```

### List with Filters

```ruby
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
```

### Bulk Delete

```ruby
client.documents.delete_bulk(ids: ["id1", "id2", "id3"])
```

### Upload File

```ruby
file = Faraday::Multipart::FilePart.new("/path/to/doc.pdf", "application/pdf")
client.documents.upload_file(file: file, container_tag: "user-123")
```

## Search

### Document Search (v3)

```ruby
results = client.search.documents(
  q: "async programming",
  limit: 10,
  rerank: true,
  include_summary: true,
  filters: { "AND" => [{ key: "topic", value: "python" }] }
)

results["results"].each do |r|
  puts "#{r["title"]} (score: #{r["score"]})"
end
```

### Memory Search (v4)

```ruby
results = client.search.memories(
  q: "user preferences",
  container_tag: "user-123",
  search_mode: "hybrid",
  limit: 5,
  threshold: 0.5
)

results["results"].each { |r| puts r["memory"] }
```

## Memories

### Forget a Memory

```ruby
client.memories.forget(container_tag: "user-123", id: "mem-id")
# Or by content:
client.memories.forget(
  container_tag: "user-123",
  content: "User prefers dark mode",
  reason: "User updated preference"
)
```

### Update a Memory

```ruby
client.memories.update_memory(
  container_tag: "user-123",
  id: "mem-id",
  new_content: "User prefers light mode now"
)
```

## Settings

```ruby
settings = client.settings.get
client.settings.update(chunk_size: 1500, should_llm_filter: true)
```

## Connections

```ruby
# Create OAuth connection
conn = client.connections.create("github",
  redirect_url: "https://myapp.com/callback",
  document_limit: 100
)
puts conn["authLink"]

# List and manage connections
client.connections.list
client.connections.import("github")
client.connections.list_documents("github")
```
