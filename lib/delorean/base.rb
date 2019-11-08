# frozen_string_literal: true

require 'active_support/time'
require 'active_record'
require 'bigdecimal'
require 'delorean/ruby'
require 'delorean/ruby/whitelists/default'
require 'delorean/cache'
require 'delorean/const'

module Delorean
  ::Delorean::Ruby.whitelist = ::Delorean::Ruby::Whitelists::Default.new

  ::Delorean::Cache.adapter = ::Delorean::Cache::Adapters::RubyCache.new(
    size_per_class: 1000
  )

  ::Delorean::Ruby.error_handler = ::Delorean::Ruby::DEFAULT_ERROR_HANDLER

  cache_callback = ::Delorean::Cache::NODE_CACHE_DEFAULT_CALLBACK

  ::Delorean::Cache.node_cache_callback = cache_callback

  NODE_CACHE_ARG = "_cache#{POST}".to_sym

  module BaseModule
    # _e is used by Marty promise_jobs to pass promise-related
    # information
    class NodeCall < Struct.new(:_e, :engine, :node, :params)
      def cloned_params
        # FIXME: evaluate() modifies params! => need to clone it.
        # This is pretty awful.  NOTE: can't sanitize params as Marty
        # patches NodeCall and modifies params to send _parent_id.
        # This whole thing needs to be redone.
        @cloned_params ||= Hash[params]
      end

      def evaluate(attr)
        if node.respond_to?(NODE_CACHE_ARG) && node.send(NODE_CACHE_ARG, _e)
          return _evaluate_with_cache(attr)
        end

        engine.evaluate(node, attr, cloned_params)
      end

      def _evaluate_with_cache(attr)
        ::Delorean::Cache.with_cache(
          klass: node,
          method: attr,
          mutable_params: cloned_params,
          params: params
        ) do
          engine.evaluate(node, attr, cloned_params)
        end
      end

      def /(args)
        case args
        when Array
          engine.eval_to_hash(node, args, cloned_params)
        when String
          evaluate(args)
        else
          raise 'non-array/string arg to /'
        end
      rescue StandardError => exc
        Delorean::Engine.grok_runtime_exception(exc)
      end

      # FIXME: % should also support string as args
      def %(args)
        raise 'non-array arg to %' unless args.is_a?(Array)

        engine.eval_to_hash(node, args, cloned_params)
      end

      # add new arguments, results in a new NodeCall
      def +(args)
        raise 'bad arg to %' unless args.is_a?(Hash)

        NodeCall.new(_e, engine, node, params.merge(args))
      end
    end

    class BaseClass
      def self._get_attr(obj, attr, _e)
        # REALLY FIXME: this really needs to be another "when" in the
        # case statement below. However, Gemini appears to create Hash
        # objects when running Delorean modules in delayed jobs that
        # return true when we called obj.instance_of?(Hash) and do not
        # work with the "case/when" matcher!!!  For now, this is a
        # hacky workaround.  This is likely some sort of Ruby bug.
        return _get_hash_attr(obj, attr, _e) if obj.instance_of?(Hash)

        # NOTE: should keep this function consistent with _index
        case obj
        when nil
          # FIXME: even Javascript which is superpermissive raises an
          # exception on null getattr.
          return nil
        when NodeCall
          return obj.evaluate(attr)
        when OpenStruct
          return obj[attr.to_sym]
        when Class
          return obj.send((attr + POST).to_sym, _e) if obj < BaseClass
        end

        begin
          return _instance_call(obj, attr, [], _e)
        rescue StandardError => exc
          raise(
            InvalidGetAttribute,
            "attr lookup failed: '#{attr}' on <#{obj.class}> #{obj} - #{exc}"
          )
        end
      end

      def self._get_hash_attr(obj, attr, _e, index_call = false)
        return obj[attr] if obj.key?(attr)

        return obj[attr.to_sym] if attr.is_a?(String) && obj.key?(attr.to_sym)

        # Shouldn't try to call the method if hash['length'] was called.
        return nil if index_call

        # Return nil when it's obviously not a method
        return nil unless attr.is_a?(String) || attr.is_a?(Symbol)

        # hash.length might be either hash['length'] or hash.length call.
        # If key is not found, check if object responds to method and call it.
        # If not succeeded, return nil, assuming that it was an attribute call.
        return nil unless obj.respond_to?(attr)

        begin
          return _instance_call(obj, attr, [], _e)
        rescue StandardError
          return nil
        end
      end

      ######################################################################

      def self._index(obj, args, _e)
        # NOTE: should keep this function consistent with _get_attr
        case obj
        when nil
          # FIXME: even Javascript which is superpermissive raises an
          # exception on null getattr.
          nil
        when Hash
          raise InvalidIndex unless args.length == 1

          _get_hash_attr(obj, args[0], _e, true)
        when NodeCall, Class, OpenStruct
          raise InvalidIndex unless args.length == 1

          _get_attr(obj, args[0], _e)
        when Array, String, MatchData
          raise InvalidIndex unless args.length <= 2 &&
                                    args[0].is_a?(Integer) &&
                                    (args[1].nil? || args[1].is_a?(Integer))

          obj[*args]
        else
          raise InvalidIndex
        end
      end

      ######################################################################

      def self._sanitize_hash(_e)
        _e.each_with_object({}) do |(k, v), h|
          h[k] = v if k.is_a?(Integer) || k =~ /\A[a-z][A-Za-z0-9_]*\z/
        end
      end

      ######################################################################

      def self._err(*args)
        ::Delorean::Ruby.error_handler.call(*args)
      end

      def self._node_call(node, _e, params)
        context = _e[:_engine]

        # a node call is being called with amended args
        return node + params if node.is_a?(NodeCall)

        engine = node.is_a?(Class) &&
          context.module_name != node.module_name ?
        context.get_import_engine(node.module_name) : context

        NodeCall.new(_e, engine, node || self, params)
      end

      ######################################################################

      def self._instance_call(obj, method, args, _e, &block)
        begin
          msg = method.to_sym
        rescue NoMethodError
          raise "bad method #{method}"
        end

        if obj.is_a?(Class) || obj.is_a?(Module)
          matcher = ::Delorean::Ruby.whitelist.class_method_matcher(
            method_name: msg
          )
          klass = obj
        else
          matcher = ::Delorean::Ruby.whitelist.matcher(method_name: msg)
          klass = obj.class
        end

        raise "no such method #{method}" unless matcher

        if matcher.match_to?
          if block
            return(
              _instance_call(obj, matcher.match_to, args, _e, &block)
            )
          else
            return(
              _instance_call(obj, matcher.match_to, args, _e)
            )
          end
        end

        matcher.match!(klass: klass, args: args)

        return obj.public_send(msg, *args) unless block

        obj.public_send(msg, *args, &block)
      end

      ######################################################################
    end
  end
end
