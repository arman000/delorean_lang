# frozen_string_literal: true

module Delorean
  module Cache
    module Adapters
      class Base
        def cache_item(klass:, cache_key:, args:)
          raise 'cache_item is not implemented'
        end

        def cache_expiring_item(klass:, cache_key:, args:, expires_at:)
          raise 'cache_item is not implemented'
        end

        def fetch_item(klass:, cache_key:, args:)
          raise 'fetch_item is not implemented'
        end

        def fetch_expiring_item(klass:, cache_key:, args:)
          raise 'fetch_item is not implemented'
        end

        def cache_key(klass:, method_name:, args:)
          raise 'cache_key is not implemented'
        end

        def clear!(klass:)
          raise 'clear! is not implemented'
        end

        def clear_all!
          raise 'clear_all! is not implemented'
        end

        # Redefine this method in descendants
        # to avoid caching calls with certain arguments
        def cache_item?(klass:, method_name:, args:)
          true
        end
      end
    end
  end
end
