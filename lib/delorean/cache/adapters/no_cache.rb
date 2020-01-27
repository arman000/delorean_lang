# frozen_string_literal: true

require_relative './base'

module Delorean
  module Cache
    module Adapters
      class NoCache < ::Delorean::Cache::Adapters::Base
        attr_reader :lookup_cache, :size_per_class

        def initialize(size_per_class: 1000); end

        def cache_item?(klass:, method_name:, args:)
          false
        end

        def cache_item(klass:, cache_key:, item:); end

        def fetch_item(klass:, cache_key:, default: nil)
          default
        end

        def cache_key(klass:, method_name:, args:)
          :no_cache_key
        end

        def clear!(klass:); end

        def clear_all!; end

        private

        def clear_outdated_items(klass:); end
      end
    end
  end
end
