# frozen_string_literal: true

require 'delorean/cache/adapters'

module Delorean
  module Cache
    NODE_CACHE_DEFAULT_CALLBACK = lambda do |klass:, method:, params:|
      {
        cache: true,
      }
    end

    class << self
      attr_accessor :adapter

      def with_cache(klass:, method:, mutable_params:, params:)
        delorean_cache_adapter = ::Delorean::Cache.adapter

        klass_name = "#{klass.name}#{::Delorean::POST}"

        cache_options = node_cache_callback.call(
          klass: klass,
          method: method,
          params: mutable_params
        )

        return yield unless cache_options[:cache]

        cache_key = delorean_cache_adapter.cache_key(
          klass: klass_name, method_name: method, args: [params]
        )

        cached_item = delorean_cache_adapter.fetch_item(
          klass: klass_name, cache_key: cache_key, default: :NF
        )

        return cached_item if cached_item != :NF

        res = yield

        delorean_cache_adapter.cache_item(
          klass: klass_name,
          cache_key: cache_key,
          item: res,
        )

        res
      end

      attr_accessor :node_cache_callback
    end
  end
end
