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
        return nil if obj.nil?

        if obj.kind_of? ActiveRecord::Base
          klass = obj.class

          return obj.read_attribute(attr) if
            klass.attribute_names.member? attr

          return obj.send(attr.to_sym) if
            klass.reflect_on_all_associations.map(&:name).member? attr.to_sym

          raise InvalidGetAttribute, "ActiveRecord lookup '#{attr}' on #{obj}"
        elsif obj.instance_of?(Hash)
          return obj[attr] if obj.member?(attr)
          return obj[attr.to_sym]
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

      def self._script_call(node_name, _e, attrs, params)
        engine = _e[:_engine]
        node_name = self.name.split('::')[-1] unless node_name

        res = engine.evaluate_attrs(node_name, attrs, params)

        return res[0] if attrs.length == 1

        # There are more than one attrs, return hash result
        Hash[* attrs.zip(res).flatten]
      end

      ######################################################################
    end
  end
end

