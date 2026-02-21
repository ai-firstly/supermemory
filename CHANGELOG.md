# Changelog

## [0.1.0] - 2025-02-21

### Added

- Core Supermemory client with full API coverage
  - Documents: add, batch_add, get, update, delete, list, delete_bulk, list_processing, upload_file
  - Search: documents (v3), memories (v4), execute
  - Memories: forget, update_memory
  - Settings: get, update
  - Connections: create, list, configure, get_by_id, get_by_tag, delete_by_id, delete_by_provider, import, list_documents, resources
  - Profile: top-level profile method
- Error handling with retry logic (exponential backoff with jitter)
- ruby-openai integration
  - `SupermemoryTools` for function calling
  - `with_supermemory` wrapper for automatic memory injection
- graph-agent integration
  - Pre-built node functions (recall_memories, store_memory, search_memories, add_memory)
  - `build_memory_graph` helper for quick setup
  - Memory-aware state schema
- langchainrb integration
  - `SupermemoryTool` with ToolDefinition for search_memory, add_memory, get_profile, forget_memory
  - `SupermemoryMemory` helper for manual memory context management
