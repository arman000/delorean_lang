require_relative './base'

module Delorean
  module Cache
    module Adapters
      class RubyCache < ::Delorean::Cache::Adapters::Base
        attr_reader :lookup_cache, :size_per_class

        def initialize(size_per_class: 1000)
          @lookup_cache = {}
          @size_per_class = size_per_class
        end

        def cache_item(klass:, cache_key:, item:)
          lookup_cache[klass] ||= {}
          clear_outdated_items(klass: klass)
          lookup_cache[klass][cache_key] = item
        end

        def fetch_item(klass:, cache_key:, default: nil)
          subh = lookup_cache.fetch(klass, default)
          return default if subh == default
          v = subh.fetch(cache_key, default)
          return default if v == default
          v
        end

        def cache_key(klass:, method_name:, args:)
          [method_name] + args.map do |arg|
            next arg.id if arg.respond_to?(:id)
            arg
          end.freeze
        end

        def clear!(klass:)
          lookup_cache[klass] = {}
        end

        def clear_all!
          @lookup_cache = {}
        end

        private

        def clear_outdated_items(klass:)
          cache_object = lookup_cache[klass]
          return unless cache_object
          return if cache_object.count < size_per_class

          max_items = (size_per_class / 5).floor
          cache_object.keys[0..max_items].each do |key|
            cache_object.delete(key)
          end
        end
      end
    end
  end
end
