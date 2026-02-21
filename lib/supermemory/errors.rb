# frozen_string_literal: true

module Supermemory
  class Error < StandardError; end

  class APIError < Error
    attr_reader :status, :body, :headers

    def initialize(message = nil, status: nil, body: nil, headers: nil)
      @status = status
      @body = body
      @headers = headers
      super(message || default_message)
    end

    private

    def default_message
      "API error (status: #{status})"
    end
  end

  class BadRequestError < APIError
    def initialize(message = nil, **kwargs)
      super(message, status: 400, **kwargs)
    end
  end

  class AuthenticationError < APIError
    def initialize(message = nil, **kwargs)
      super(message, status: 401, **kwargs)
    end
  end

  class PermissionDeniedError < APIError
    def initialize(message = nil, **kwargs)
      super(message, status: 403, **kwargs)
    end
  end

  class NotFoundError < APIError
    def initialize(message = nil, **kwargs)
      super(message, status: 404, **kwargs)
    end
  end

  class ConflictError < APIError
    def initialize(message = nil, **kwargs)
      super(message, status: 409, **kwargs)
    end
  end

  class UnprocessableEntityError < APIError
    def initialize(message = nil, **kwargs)
      super(message, status: 422, **kwargs)
    end
  end

  class RateLimitError < APIError
    def initialize(message = nil, **kwargs)
      super(message, status: 429, **kwargs)
    end
  end

  class InternalServerError < APIError
    def initialize(message = nil, **kwargs)
      super(message, status: 500, **kwargs)
    end
  end

  class APIConnectionError < Error; end
  class APITimeoutError < APIConnectionError; end

  # @private
  ERROR_MAP = {
    400 => BadRequestError,
    401 => AuthenticationError,
    403 => PermissionDeniedError,
    404 => NotFoundError,
    409 => ConflictError,
    422 => UnprocessableEntityError,
    429 => RateLimitError
  }.freeze
end
