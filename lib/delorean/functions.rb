# frozen_string_literal: true

module Delorean
  module Functions
    def delorean_fn(name, _options = {}, &block)
      any_args = Delorean::Ruby::Whitelists::Matchers::Arguments::ANYTHING

      define_singleton_method(name, block)

      ::Delorean::Ruby.whitelist.add_class_method name do |method|
        method.called_on self, with: any_args
      end

      name.to_sym
    end

    # FIXME: IDEA: we just make :cache an argument to delorean_fn.
    # That way, we don't need the cached_ flavors.  It'll make all
    # this code a lot simpler.  We should also just add the :private
    # mechanism here.

    # By default implements a VERY HACKY class-based (per process) caching
    # mechanism for database lookup results.  Issues include: cached
    # values are ActiveRecord objects.  Query results can be very
    # large lists which we count as one item in the cache.  Caching
    # mechanism will result in large processes.
    def cached_delorean_fn(name, options = {})
      delorean_fn(name, options) do |*args|
        delorean_cache_adapter = ::Delorean::Cache.adapter
        # Check if caching should be performed
        next yield(*args) unless delorean_cache_adapter.cache_item?(
          klass: self, method_name: name, args: args
        )

        cache_key = delorean_cache_adapter.cache_key(
          klass: self, method_name: name, args: args
        )
        cached_item = delorean_cache_adapter.fetch_item(
          klass: self, cache_key: cache_key, default: :NF
        )

        next cached_item if cached_item != :NF

        res = yield(*args)

        delorean_cache_adapter.cache_item(
          klass: self, cache_key: cache_key, item: res
        )

        # Since we're caching this object and don't want anyone
        # changing it.  FIXME: ideally should freeze this object
        # recursively.
        res.freeze if res.respond_to?(:freeze)

        res
      end
    end

    def clear_lookup_cache!
      ::Delorean::Cache.adapter.clear!(klass: self)
    end
  end
end
