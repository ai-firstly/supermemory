# Configuration

## Global Configuration

Set defaults that apply to all client instances:

```ruby
Supermemory.configure do |config|
  config.api_key = ENV["SUPERMEMORY_API_KEY"]
  config.base_url = "https://api.supermemory.ai"  # default
  config.timeout = 60                              # seconds, default
  config.max_retries = 2                           # default
  config.extra_headers = {}                        # additional HTTP headers
end
```

## Per-Client Configuration

Override defaults for individual clients:

```ruby
client = Supermemory::Client.new(
  api_key: "sk-...",
  base_url: "https://custom-endpoint.com",
  timeout: 30,
  max_retries: 3,
  extra_headers: { "X-Custom-Header" => "value" }
)
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SUPERMEMORY_API_KEY` | Default API key | (none) |
| `SUPERMEMORY_BASE_URL` | Default base URL | `https://api.supermemory.ai` |

## Retry Behavior

The client automatically retries requests on transient failures:

- **Retryable status codes**: 408, 409, 429, 500, 502, 503, 504
- **Backoff**: Exponential with jitter (0.5s base, 8s max)
- **Max retries**: Configurable via `max_retries` (default: 2)

```ruby
# Disable retries
client = Supermemory::Client.new(api_key: "sk-...", max_retries: 0)

# More aggressive retries
client = Supermemory::Client.new(api_key: "sk-...", max_retries: 5)
```
