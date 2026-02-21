# API Reference

## Supermemory::Client

### Constructor

```ruby
Supermemory::Client.new(
  api_key: String,           # Required (or set via config/env)
  base_url: String,          # Default: "https://api.supermemory.ai"
  timeout: Integer,          # Default: 60 seconds
  max_retries: Integer,      # Default: 2
  extra_headers: Hash        # Default: {}
)
```

### Convenience Methods

| Method | Description |
|--------|-------------|
| `add(content:, **options)` | Add a document (delegates to `documents.add`) |
| `profile(container_tag:, q:, threshold:)` | Get user profile |

### Resource Accessors

| Method | Returns |
|--------|---------|
| `documents` | `Supermemory::Resources::Documents` |
| `search` | `Supermemory::Resources::Search` |
| `memories` | `Supermemory::Resources::Memories` |
| `settings` | `Supermemory::Resources::Settings` |
| `connections` | `Supermemory::Resources::Connections` |

### Low-Level HTTP

| Method | Description |
|--------|-------------|
| `get(path, params)` | GET request |
| `post(path, body)` | POST request |
| `patch(path, body)` | PATCH request |
| `delete(path, body)` | DELETE request |
| `multipart_post(path, body)` | Multipart POST |

## Supermemory::Resources::Documents

| Method | Description |
|--------|-------------|
| `add(content:, container_tag:, custom_id:, entity_context:, metadata:)` | Create a document |
| `batch_add(documents:, container_tag:, metadata:)` | Batch create documents |
| `get(id)` | Get a document by ID |
| `update(id, **options)` | Update a document |
| `delete(id)` | Delete a document |
| `list(filters:, include_content:, limit:, page:, sort:, order:)` | List documents |
| `delete_bulk(ids:, container_tags:)` | Bulk delete documents |
| `list_processing` | List processing documents |
| `upload_file(file:, file_type:, mime_type:, metadata:, container_tag:)` | Upload a file |

## Supermemory::Resources::Search

| Method | Description |
|--------|-------------|
| `documents(q:, ...)` | Search documents (v3 API) |
| `execute(**params)` | Alias for `documents` |
| `memories(q:, container_tag:, ...)` | Search memories (v4 API) |

## Supermemory::Resources::Memories

| Method | Description |
|--------|-------------|
| `forget(container_tag:, id:, content:, reason:)` | Soft-delete a memory |
| `update_memory(container_tag:, new_content:, id:, content:, metadata:)` | Update (version) a memory |

## Supermemory::Resources::Settings

| Method | Description |
|--------|-------------|
| `get` | Get current settings |
| `update(**options)` | Update settings |

## Supermemory::Resources::Connections

| Method | Description |
|--------|-------------|
| `create(provider, ...)` | Create an OAuth connection |
| `list(container_tags:)` | List connections |
| `configure(connection_id, resources:)` | Configure a connection |
| `get_by_id(connection_id)` | Get connection by ID |
| `get_by_tag(provider, container_tags:)` | Get connection by provider + tags |
| `delete_by_id(connection_id)` | Delete by ID |
| `delete_by_provider(provider, container_tags:)` | Delete by provider |
| `import(provider, container_tags:)` | Trigger import/sync |
| `list_documents(provider, container_tags:)` | List connection documents |
| `resources(connection_id, page:, per_page:)` | List available resources |

## Supermemory::Configuration

| Attribute | Type | Default |
|-----------|------|---------|
| `api_key` | String | `ENV["SUPERMEMORY_API_KEY"]` |
| `base_url` | String | `"https://api.supermemory.ai"` |
| `timeout` | Integer | `60` |
| `max_retries` | Integer | `2` |
| `extra_headers` | Hash | `{}` |
