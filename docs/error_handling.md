# Error Handling

## Error Hierarchy

```
Supermemory::Error                    # Base error
├── Supermemory::APIError             # HTTP API errors (with status, body, headers)
│   ├── BadRequestError        (400)
│   ├── AuthenticationError    (401)
│   ├── PermissionDeniedError  (403)
│   ├── NotFoundError          (404)
│   ├── ConflictError          (409)
│   ├── UnprocessableEntityError (422)
│   ├── RateLimitError         (429)
│   └── InternalServerError    (500)
├── Supermemory::APIConnectionError   # Network-level errors
│   └── Supermemory::APITimeoutError  # Request timeout
```

## Handling Errors

```ruby
begin
  client.add(content: "test")
rescue Supermemory::AuthenticationError => e
  puts "Invalid API key: #{e.message}"
  puts "Status: #{e.status}"           # => 401
  puts "Body: #{e.body}"               # => { "error" => "..." }
  puts "Headers: #{e.headers}"
rescue Supermemory::RateLimitError => e
  puts "Rate limited, retry later"
rescue Supermemory::NotFoundError => e
  puts "Resource not found"
rescue Supermemory::InternalServerError => e
  puts "Server error (retries exhausted)"
rescue Supermemory::APIConnectionError => e
  puts "Connection failed: #{e.message}"
rescue Supermemory::APITimeoutError => e
  puts "Request timed out"
end
```

## Automatic Retries

Retries are applied automatically for transient errors:

- **Status codes**: 408, 409, 429, 500, 502, 503, 504
- **Backoff**: Exponential with jitter
- **Default retries**: 2

Configure via `max_retries`:

```ruby
# No retries
client = Supermemory::Client.new(api_key: "sk-...", max_retries: 0)

# More retries
client = Supermemory::Client.new(api_key: "sk-...", max_retries: 5)
```
