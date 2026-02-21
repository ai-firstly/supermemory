# Supermemory Ruby SDK Documentation

Official Ruby SDK for [Supermemory](https://supermemory.ai) — Memory API for the AI era.

## Guides

| Document | Description |
|----------|-------------|
| [Quickstart](quickstart.md) | Installation, configuration, and first steps |
| [Configuration](configuration.md) | Global and per-client configuration options |
| [Core API](core_api.md) | Documents, Search, Memories, Settings, Connections |
| [Integrations](integrations.md) | OpenAI, graph-agent, and langchainrb integrations |
| [Error Handling](error_handling.md) | Error classes, retries, and best practices |
| [API Reference](api_reference.md) | Full reference for every class and method |

## Source Layout

```
lib/
  supermemory.rb                          # Entry point & requires
  supermemory/
    version.rb                            # Version constant
    errors.rb                             # Error hierarchy
    configuration.rb                      # Global configuration
    client.rb                             # HTTP client with retry logic
    resources/
      base.rb                             # Base resource class
      documents.rb                        # Document CRUD operations
      search.rb                           # v3 document search & v4 memory search
      memories.rb                         # Memory forget & update
      settings.rb                         # Settings management
      connections.rb                      # OAuth connection management
    integrations/
      openai.rb                           # ruby-openai integration
      graph_agent.rb                      # graph-agent integration
      langchain.rb                        # langchainrb integration
```
