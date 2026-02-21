# frozen_string_literal: true

module Supermemory
  class Configuration
    attr_accessor :api_key, :base_url, :timeout, :max_retries, :extra_headers

    def initialize
      @api_key = ENV.fetch("SUPERMEMORY_API_KEY", nil)
      @base_url = ENV.fetch("SUPERMEMORY_BASE_URL", "https://api.supermemory.ai")
      @timeout = 60
      @max_retries = 2
      @extra_headers = {}
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end
