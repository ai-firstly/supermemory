# frozen_string_literal: true

require_relative "supermemory/version"
require_relative "supermemory/errors"
require_relative "supermemory/configuration"
require_relative "supermemory/client"
require_relative "supermemory/resources/base"
require_relative "supermemory/resources/documents"
require_relative "supermemory/resources/search"
require_relative "supermemory/resources/memories"
require_relative "supermemory/resources/settings"
require_relative "supermemory/resources/connections"

module Supermemory
  class << self
    # Create a new client instance
    # @param options [Hash] Client options (api_key:, base_url:, timeout:, max_retries:)
    # @return [Supermemory::Client]
    def new(**options)
      Client.new(**options)
    end
  end
end
