# frozen_string_literal: true

require 'delorean/ruby/whitelists/base'

module Delorean
  module Ruby
    module Whitelists
      class Default < ::Delorean::Ruby::Whitelists::Base
        TI_TYPES   = [Time, ActiveSupport::TimeWithZone].freeze
        DT_TYPES   = [Date] + TI_TYPES
        NUM_OR_STR = [Numeric, String].freeze
        NUM_OR_NIL = [nil, Integer].freeze

        def initialize_hook
          _add_default_methods
        end

        private

        def _add_default_methods
          add_method :attributes do |method|
            method.called_on ActiveRecord::Base
            method.called_on ActiveRecord::Relation
          end

          add_method :between? do |method|
            method.called_on String, with: [String, String]
            method.called_on Numeric, with: [Numeric, Numeric]
          end

          add_method :between, match_to: :between?

          add_method :compact do |method|
            method.called_on Array
            method.called_on Hash
          end

          add_method :to_set do |method|
            method.called_on Array
          end

          add_method :flatten do |method|
            method.called_on Array, with: [NUM_OR_NIL]
          end

          add_method :length do |method|
            method.called_on String
            method.called_on Enumerable
          end

          add_method :max do |method|
            method.called_on Array
          end

          add_method :member, match_to: :member?

          add_method :member? do |method|
            method.called_on Enumerable, with: [Object]
          end

          add_method :empty, match_to: :empty?

          add_method :empty? do |method|
            method.called_on Enumerable
          end

          add_method :except do |method|
            method.called_on Hash, with: [String] + [[nil, String]] * 9
          end

          add_method :reverse do |method|
            method.called_on Array
          end

          add_method :slice do |method|
            method.called_on Array, with: [Integer, Integer]
          end

          add_method :each_slice do |method|
            method.called_on Array, with: [Integer]
          end

          add_method :sort do |method|
            method.called_on Array
          end

          add_method :split do |method|
            method.called_on String, with: [String]
          end

          add_method :uniq do |method|
            method.called_on Array
          end

          add_method :sum do |method|
            method.called_on Array
          end

          add_method :transpose do |method|
            method.called_on Array
          end

          add_method :join do |method|
            method.called_on Array, with: [String]
          end

          add_method :zip do |method|
            method.called_on Array, with: [Array, [Array, nil], [Array, nil]]
          end

          add_method :index do |method|
            method.called_on Array, with: [[Object]]
          end

          add_method :product do |method|
            method.called_on Array, with: [Array]
          end

          add_method :first do |method|
            method.called_on ActiveRecord::Relation, with: [NUM_OR_NIL]
            method.called_on Enumerable, with: [NUM_OR_NIL]
          end

          add_method :last do |method|
            method.called_on ActiveRecord::Relation, with: [NUM_OR_NIL]
            method.called_on Enumerable, with: [NUM_OR_NIL]
          end

          add_method :intersection do |method|
            method.called_on Set, with: [Enumerable]
          end

          add_method :union do |method|
            method.called_on Set, with: [Enumerable]
          end

          add_method :keys do |method|
            method.called_on Hash
          end

          add_method :values do |method|
            method.called_on Hash
          end

          add_method :fetch do |method|
            method.called_on Hash, with: [Object, [Object]]
          end

          add_method :upcase do |method|
            method.called_on String
          end

          add_method :downcase do |method|
            method.called_on String
          end

          add_method :match do |method|
            method.called_on String, with: [[String], NUM_OR_NIL]
          end

          add_method :iso8601 do |method|
            DT_TYPES.each do |type|
              method.called_on type
            end
          end

          add_method :hour do |method|
            DT_TYPES.each do |type|
              method.called_on type
            end
          end

          add_method :min do |method|
            (DT_TYPES + [Array]).each do |type|
              method.called_on type
            end
          end

          add_method :sec do |method|
            DT_TYPES.each do |type|
              method.called_on type
            end
          end

          add_method :to_date do |method|
            (DT_TYPES + [String]).each do |type|
              method.called_on type
            end
          end

          add_method :to_time do |method|
            (DT_TYPES + [String]).each do |type|
              method.called_on type
            end
          end

          add_method :month do |method|
            DT_TYPES.each do |type|
              method.called_on type
            end
          end

          add_method :day do |method|
            DT_TYPES.each do |type|
              method.called_on type
            end
          end

          add_method :year do |method|
            DT_TYPES.each do |type|
              method.called_on type
            end
          end

          add_method :next_month do |method|
            DT_TYPES.each do |type|
              method.called_on type, with: [NUM_OR_NIL]
            end
          end

          add_method :prev_month do |method|
            DT_TYPES.each do |type|
              method.called_on type, with: [NUM_OR_NIL]
            end
          end

          add_method :beginning_of_month do |method|
            DT_TYPES.each do |type|
              method.called_on type
            end
          end

          add_method :end_of_month do |method|
            DT_TYPES.each do |type|
              method.called_on type
            end
          end

          add_method :next_day do |method|
            DT_TYPES.each do |type|
              method.called_on type, with: [NUM_OR_NIL]
            end
          end

          add_method :prev_day do |method|
            DT_TYPES.each do |type|
              method.called_on type, with: [NUM_OR_NIL]
            end
          end

          add_method :to_i do |method|
            (NUM_OR_STR + TI_TYPES).each do |type|
              method.called_on type
            end
          end

          add_method :to_f do |method|
            (NUM_OR_STR + TI_TYPES).each do |type|
              method.called_on type
            end
          end

          add_method :to_d do |method|
            NUM_OR_STR.each do |type|
              method.called_on type
            end
          end

          add_method :to_s do |method|
            method.called_on Object
          end

          add_method :to_a do |method|
            method.called_on Object
          end

          add_method :to_json do |method|
            method.called_on Object
          end

          add_method :abs do |method|
            method.called_on Numeric
          end

          add_method :round do |method|
            method.called_on Numeric, with: [[nil, Integer]]
          end

          add_method :ceil do |method|
            method.called_on Numeric
          end

          add_method :floor do |method|
            method.called_on Numeric
          end

          add_method :truncate do |method|
            method.called_on Numeric, with: [[nil, Integer]]
          end
        end
      end
    end
  end
end
