# frozen_string_literal: true

module Supermemory
  module Resources
    class Base
      # @return [Supermemory::Client]
      attr_reader :client

      # @param client [Supermemory::Client]
      def initialize(client)
        @client = client
      end
    end
  end
end
