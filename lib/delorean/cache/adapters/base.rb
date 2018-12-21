module Delorean
  module Cache
    module Adapters
      class Base
        def cache_item(klass:, method_name:, args:)
          raise 'cache_item is not implemented'
        end

        def fetch_item(klass:, method_name:, args:)
          raise 'fetch_item is not implemented'
        end

        def clear!(klass:)
          raise 'clear! is not implemented'
        end

        def clear_all!
          raise 'clear_all! is not implemented'
        end
      end
    end
  end
end
