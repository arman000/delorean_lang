require 'delorean/functions'

module Delorean
  module BaseModule

    class BaseClass
      # Using extend and include to get both constants and methods.
      # Not sure if how to do this only with extend.
      extend Delorean::Functions
      include Delorean::Functions

      ######################################################################

      def self._get_attr(obj, attr)
        if obj.kind_of? ActiveRecord::Base
          return obj.read_attribute(attr) if
            obj.class.attribute_names.member? attr

          raise InvalidGetAttribute, "ActiveRecord lookup '#{attr}' on #{obj}"
        elsif obj.instance_of?(Class) && obj < BaseClass
          # FIXME: do something
          puts 'X'*30
        end

        raise InvalidGetAttribute, "bad attribute lookup '#{attr}' on #{obj}"
      end

      ######################################################################

      def self._fetch_param(_e, name)
        begin
          _e.fetch(name)
        rescue KeyError
          raise UndefinedParamError, "undefined parameter #{name}"
        end
      end

      ######################################################################

    end
  end
end

