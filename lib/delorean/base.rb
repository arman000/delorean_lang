require 'delorean/functions'

module Delorean
  module BaseModule

    class BaseClass
      # Using extend and include to get both constants and methods.
      # Not sure if how to do this only with extend.
      extend Delorean::Functions
      include Delorean::Functions

      ######################################################################

      def self._get_attr(obj, attr, _e)
        return nil if obj.nil?

        if obj.kind_of? ActiveRecord::Base
          klass = obj.class

          return obj.read_attribute(attr) if
            klass.attribute_names.member? attr

          return obj.send(attr.to_sym) if
            klass.reflect_on_all_associations.map(&:name).member? attr.to_sym

          raise InvalidGetAttribute, "ActiveRecord lookup '#{attr}' on #{obj}"
        elsif obj.instance_of?(Hash)
          return obj.member?(attr) ? obj[attr] : obj[attr.to_sym]
        elsif obj.instance_of?(Class) && (obj < BaseClass)
          return obj.send((attr + POST).to_sym, _e)
        end

        raise InvalidGetAttribute, "bad attribute lookup '#{attr}' on #{obj}"
      end

      ######################################################################

      def self._index(obj, args, _e)
        if obj.instance_of?(Hash)
          raise InvalidIndex unless args.length == 1
          obj[args[0]]
        elsif obj.instance_of?(Array)
          raise InvalidIndex unless args.length < 2
          raise InvalidIndex unless
            args[0].is_a?(Fixnum) && (!args[1] || args[1].is_a?(Fixnum))
          obj[*args]
        else
          raise InvalidIndex
        end
      end

      ######################################################################

      def self._script_call(node, mname, _e, attrs, params)
        context = _e[:_engine]
        node ||= self

        engine = mname ? context.get_import_engine(mname) : context
        engine.evaluate_attrs_hash(node, attrs, params)
      end

      ######################################################################
    end
  end
end

