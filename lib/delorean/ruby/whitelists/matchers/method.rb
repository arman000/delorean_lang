require 'delorean/ruby/whitelists/matchers/arguments'

module Delorean
  module Ruby
    module Whitelists
      module Matchers
        class Method
          attr_reader :method_name, :match_to, :arguments_matchers

          def initialize(method_name:, match_to: nil)
            @method_name = method_name
            @match_to = match_to
            @arguments_matchers = []

            yield self if block_given?
          end

          def called_on(klass, with: [])
            matcher = Ruby::Whitelists::Matchers::Arguments.new(
              called_on: klass, method_name: method_name, with: with
            )

            arguments_matchers << matcher
          end

          def matcher(klass:)
            matcher = arguments_matchers.find do
              |matcher_object| klass <= matcher_object.called_on
            end

            raise "no such method #{method_name} for #{klass}" if matcher.nil?
            matcher
          end

          def match!(klass:, args:)
            matcher(klass: klass).match!(args: args)
          end

          def match_to?
            !match_to.nil?
          end
        end
      end
    end
  end
end
