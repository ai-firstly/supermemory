# frozen_string_literal: true

require "faraday"
require "faraday/multipart"
require "json"

module Supermemory
  class Client
    RETRYABLE_STATUS_CODES = [408, 409, 429, 500, 502, 503, 504].freeze
    INITIAL_RETRY_DELAY = 0.5
    MAX_RETRY_DELAY = 8.0

    attr_reader :api_key, :base_url, :timeout, :max_retries

    # @param api_key [String, nil] API key (defaults to SUPERMEMORY_API_KEY env var)
    # @param base_url [String, nil] Base URL (defaults to https://api.supermemory.ai)
    # @param timeout [Integer] Request timeout in seconds (default: 60)
    # @param max_retries [Integer] Max retry attempts (default: 2)
    # @param extra_headers [Hash] Additional headers to send with every request
    def initialize(api_key: nil, base_url: nil, timeout: nil, max_retries: nil, extra_headers: {})
      config = Supermemory.configuration
      @api_key = api_key || config.api_key
      @base_url = base_url || config.base_url
      @timeout = timeout || config.timeout
      @max_retries = max_retries || config.max_retries
      @extra_headers = extra_headers.merge(config.extra_headers)

      unless @api_key
        raise Supermemory::Error.new("API key is required. Set via Supermemory.configure or pass api_key:")
      end
    end

    # Top-level convenience: add a document
    # @param content [String] Text, URL, or file content
    # @param options [Hash] Additional parameters (container_tag, custom_id, metadata, entity_context)
    # @return [Hash] { "id" => "...", "status" => "..." }
    def add(content:, **options)
      documents.add(content: content, **options)
    end

    # Top-level convenience: get user profile
    # @param container_tag [String] User/project identifier
    # @param q [String, nil] Optional search query
    # @param threshold [Float, nil] Score threshold for search results
    # @return [Hash]
    def profile(container_tag:, q: nil, threshold: nil)
      body = { container_tag: container_tag }
      body[:q] = q if q
      body[:threshold] = threshold if threshold
      post("/v4/profile", body)
    end

    # @return [Supermemory::Resources::Documents]
    def documents
      @documents ||= Resources::Documents.new(self)
    end

    # @return [Supermemory::Resources::Search]
    def search
      @search ||= Resources::Search.new(self)
    end

    # @return [Supermemory::Resources::Memories]
    def memories
      @memories ||= Resources::Memories.new(self)
    end

    # @return [Supermemory::Resources::Settings]
    def settings
      @settings ||= Resources::Settings.new(self)
    end

    # @return [Supermemory::Resources::Connections]
    def connections
      @connections ||= Resources::Connections.new(self)
    end

    # Low-level HTTP methods

    # @param path [String]
    # @param params [Hash, nil]
    # @return [Hash, nil]
    def get(path, params = nil)
      request(:get, path, params: params)
    end

    # @param path [String]
    # @param body [Hash, nil]
    # @return [Hash, nil]
    def post(path, body = nil)
      request(:post, path, body: body)
    end

    # @param path [String]
    # @param body [Hash, nil]
    # @return [Hash, nil]
    def patch(path, body = nil)
      request(:patch, path, body: body)
    end

    # @param path [String]
    # @param body [Hash, nil]
    # @return [Hash, nil]
    def delete(path, body = nil)
      request(:delete, path, body: body)
    end

    # @param path [String]
    # @param body [Hash]
    # @return [Hash, nil]
    def multipart_post(path, body)
      request(:post, path, body: body, multipart: true)
    end

    private

    def request(method, path, body: nil, params: nil, multipart: false)
      attempts = 0

      begin
        response = connection(multipart: multipart).run_request(method, path, nil, nil) do |req|
          req.params = params if params
          if multipart
            body.each { |k, v| req.body[k] = v }
          elsif body
            req.body = body.to_json
          end
        end

        handle_response(response)
      rescue Faraday::TimeoutError => e
        raise Supermemory::APITimeoutError.new("Request timed out: #{e.message}")
      rescue Faraday::ConnectionFailed => e
        raise Supermemory::APIConnectionError.new("Connection failed: #{e.message}")
      rescue Supermemory::APIError => e
        attempts += 1
        if attempts <= @max_retries && retryable?(e.status)
          sleep(retry_delay(attempts))
          retry
        end
        raise
      end
    end

    def handle_response(response)
      status = response.status
      body = parse_body(response.body)
      headers = response.headers

      return body if status >= 200 && status < 300

      error_class = ERROR_MAP[status] || (status >= 500 ? InternalServerError : APIError)
      message = body.is_a?(Hash) ? (body["error"] || body["message"] || body.to_s) : body.to_s
      raise error_class.new(message, status: status, body: body, headers: headers)
    end

    def parse_body(body)
      return nil if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      body
    end

    def connection(multipart: false)
      @connections_cache ||= {}
      cache_key = multipart ? :multipart : :json
      @connections_cache[cache_key] ||= Faraday.new(url: @base_url) do |f|
        f.options.timeout = @timeout
        f.options.open_timeout = 5
        if multipart
          f.request :multipart
        else
          f.headers["Content-Type"] = "application/json"
        end
        f.headers["Authorization"] = "Bearer #{@api_key}"
        @extra_headers.each { |k, v| f.headers[k.to_s] = v.to_s }
        f.adapter Faraday.default_adapter
      end
    end

    def retryable?(status)
      RETRYABLE_STATUS_CODES.include?(status)
    end

    def retry_delay(attempt)
      delay = INITIAL_RETRY_DELAY * (2**(attempt - 1))
      delay = [delay, MAX_RETRY_DELAY].min
      jitter = delay * 0.25 * ((rand * 2) - 1)
      delay + jitter
    end
  end
end
