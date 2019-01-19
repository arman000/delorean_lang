module Delorean
  module Ruby
    module Whitelists
      module Matchers
        class Arguments
          attr_reader :called_on, :method_name, :with

          def initialize(called_on:, method_name:, with: [])
            @called_on = called_on
            @method_name = method_name
            @with = with
          end

          def match!(args:)
            raise "too many args to #{method_name}" if args.size > with.size

            with.each_with_index do |s, i|
              arg_signature = Array(s)

              arg = args[i]

              # Sometimes signature contains extra elements that can be nil.
              # In that case we allow it to not be passed.
              # For example .first and .first(4)
              next if arg_signature.member?(nil) && i >= args.size

              next if valid_argument?(arg_signature: arg_signature, arg: arg)

              bad_arg_error(arg_signature: arg_signature, index: i, arg: arg)
            end
          end

          private

          def valid_argument?(arg_signature:, arg:)
            arg_signature.any? { |sc| sc && arg.class <= sc }
          end

          def bad_arg_error(arg_signature:, index:, arg:)
            arg_error = "#{arg}/#{arg.class} #{arg_signature}"
            raise "bad arg #{index}, method #{method_name}: #{arg_error}"
          end
        end
      end
    end
  end
end
