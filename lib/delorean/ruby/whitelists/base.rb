# frozen_string_literal: true

require 'delorean/ruby/whitelists/whitelist_error'
require 'delorean/ruby/whitelists/matchers'

module Delorean
  module Ruby
    module Whitelists
      class Base
        attr_reader :matchers
        attr_reader :class_method_matchers

        def add_method(method_name, match_to: nil, &block)
          return method_name_error unless method_name.is_a?(Symbol)
          return block_and_match_error if !match_to.nil? && block_given?

          unless match_to.nil?
            return add_matched_method(
              method_name: method_name, match_to: match_to
            )
          end

          matcher = matchers[method_name.to_sym]

          return matcher.extend_matcher(&block) if matcher

          matchers[method_name.to_sym] = method_matcher_class.new(
            method_name: method_name, &block
          )
        end

        def add_class_method(method_name, match_to: nil, &block)
          return method_name_error unless method_name.is_a?(Symbol)
          return block_and_match_error if !match_to.nil? && block_given?

          unless match_to.nil?
            return add_class_matched_method(
              method_name: method_name, match_to: match_to
            )
          end

          matcher = class_method_matchers[method_name.to_sym]

          return matcher.extend_matcher(&block) if matcher

          class_method_matchers[method_name.to_sym] = method_matcher_class.new(
            method_name: method_name, &block
          )
        end

        def matcher(method_name:)
          matchers[method_name.to_sym]
        end

        def class_method_matcher(method_name:)
          class_method_matchers[method_name.to_sym]
        end

        private

        def initialize
          @matchers = {}
          @class_method_matchers = {}

          initialize_hook
        end

        def add_matched_method(method_name:, match_to:)
          correct_match_to = match_to.is_a?(String) || match_to.is_a?(Symbol)
          return wrong_match_to_error unless correct_match_to

          matcher = method_matcher_class.new(
            method_name: method_name, match_to: match_to.to_sym
          )

          matchers[method_name.to_sym] = matcher
        end

        def add_class_matched_method(method_name:, match_to:)
          correct_match_to = match_to.is_a?(String) || match_to.is_a?(Symbol)
          return wrong_match_to_error unless correct_match_to

          matcher = method_matcher_class.new(
            method_name: method_name, match_to: match_to.to_sym
          )

          class_method_matchers[method_name.to_sym] = matcher
        end

        def block_and_match_error
          raise(
            ::Delorean::Ruby::Whitelists::WhitelistError,
            'Method can not receive match_to and a block the same time'
          )
        end

        def wrong_match_to_error
          raise(
            ::Delorean::Ruby::Whitelists::WhitelistError,
            'match_to should either be a string or a symbol'
          )
        end

        def method_name_error
          raise(
            ::Delorean::Ruby::Whitelists::WhitelistError,
            'First attribute of add_method should be a symbol'
          )
        end

        def method_matcher_class
          ::Delorean::Ruby::Whitelists::Matchers::Method
        end
      end
    end
  end
end
