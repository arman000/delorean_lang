require 'active_support/time'

module Delorean

  # FIXME: the whitelist is quite hacky.  It's currently difficult to
  # override it.  A user will likely want to directly modify this
  # hash.  The whole whitelist mechanism should be eventually
  # rethought.
  RUBY_WHITELIST = {
    compact:	[Array],
    flatten:	[Array, [Fixnum, nil]],
    length: 	[[Array, String]],
    max: 	[Array],
    member:	"member?",
    member?:	[Array, [Fixnum, String]],
    reverse: 	[Array],
    slice:    	[Array, Fixnum, Fixnum],
    sort: 	[Array],
    split:	[String, String],
    uniq: 	[Array],

    hour:	[[Date, Time, ActiveSupport::TimeWithZone]],
    min:	[[Date, Time, ActiveSupport::TimeWithZone, Array]],
    sec:	[[Date, Time, ActiveSupport::TimeWithZone]],
    to_date:	[[Date, Time, ActiveSupport::TimeWithZone]],

    month:	[[Date, Time, ActiveSupport::TimeWithZone]],
    day:	[[Date, Time, ActiveSupport::TimeWithZone]],
    year:	[[Date, Time, ActiveSupport::TimeWithZone]],

    to_i:	[[Numeric, String]],
    to_f:	[[Numeric, String]],
    to_d:	[[Numeric, String]],
    to_s:	[Object],
    abs:	[Numeric],
    round:	[Numeric, [nil, Integer]],
  }

  module BaseModule
    class NodeCall
      attr_reader :engine, :node, :params
      def initialize(engine, node, params)
        @engine, @node, @params = engine, node, params
      end

      def evaluate(attr)
        engine.evaluate(node, attr, params)
      end

      def %(args)
        raise "bad arg to %" unless args.is_a?(Array)

        args.each_with_object({}) { |attr, h|
          h[attr] = evaluate(attr)
        }
      end
    end

    class BaseClass

      def self._get_attr(obj, attr, _e)
        return nil if obj.nil?

        # NOTE: should keep this function consistent with _index

        if obj.kind_of? ActiveRecord::Base
          klass = obj.class

          return obj.read_attribute(attr) if
            klass.attribute_names.member? attr

          return obj.send(attr.to_sym) if
            klass.reflect_on_all_associations.map(&:name).member? attr.to_sym

          raise InvalidGetAttribute, "ActiveRecord lookup '#{attr}' on #{obj}"
        elsif obj.instance_of?(NodeCall)
          return obj.evaluate(attr)
        elsif obj.instance_of?(Hash)
          return obj.member?(attr) ? obj[attr] : obj[attr.to_sym]
        elsif obj.instance_of?(Class) && (obj < BaseClass)
          return obj.send((attr + POST).to_sym, _e)
        end

        raise InvalidGetAttribute, "bad attribute lookup '#{attr}' on #{obj}"
      end

      ######################################################################

      def self._index(obj, args, _e)
        return nil if obj.nil?

        # NOTE: should keep this function consistent with _get_attr

        if obj.instance_of?(Hash) || obj.kind_of?(ActiveRecord::Base) ||
            obj.instance_of?(NodeCall) || obj.instance_of?(Class)
          raise InvalidIndex unless args.length == 1
          _get_attr(obj, args[0], _e)
        elsif obj.instance_of?(Array)
          raise InvalidIndex unless args.length <= 2
          raise InvalidIndex unless
            args[0].is_a?(Fixnum) && (!args[1] || args[1].is_a?(Fixnum))
          obj[*args]
        else
          raise InvalidIndex
        end
      end

      ######################################################################

      def self._err(*args)
        str = args.map(&:to_s).join(", ")
        raise str
      end

      def self._node_call(node, mname, _e, params)
        context = _e[:_engine]
        node ||= self

        engine = mname ? context.get_import_engine(mname) : context
        NodeCall.new(engine, node, params)
      end

      ######################################################################

      def self._instance_call(obj, method, args)
        begin
          msg = method.to_sym
        rescue NoMethodError
          raise "bad method #{method}"
        end

        sig = RUBY_WHITELIST[msg]

        raise "no such method #{method}" unless sig

        # if sig is a string, then method mapped to another name
        return _instance_call(obj, sig, args) if sig.is_a? String

        raise "too many args to #{method}" if args.length>(sig.length-1)

        arglist = [obj] + args

        sig.each_with_index { |s, i|
          s = [s] unless s.is_a?(Array)

          ok, ai = false, arglist[i]
          s.each { |sc|
            if (sc.nil? && i>=arglist.length) || (sc && ai.class <= sc)
              ok = true
              break
            end
          }
          raise "bad arg #{i} to method #{method}: #{ai}/#{ai.class} #{s}" unless ok
        }

        obj.send(msg, *args)
      end

      ######################################################################
    end
  end
end

