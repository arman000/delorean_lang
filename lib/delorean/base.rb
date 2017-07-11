require 'active_support/time'
require 'active_record'
require 'bigdecimal'

module Delorean

  # FIXME: add string.gsub; Also, should be able to index regex
  # matches.  Need string.length.

  DT_TYPES = [Date, Time, ActiveSupport::TimeWithZone]

  # FIXME: the whitelist is quite hacky.  It's currently difficult to
  # override it.  A user will likely want to directly modify this
  # hash.  The whole whitelist mechanism should be eventually
  # rethought.
  RUBY_WHITELIST = {
    attributes:         [ActiveRecord::Base],
    between?:           [[Numeric, String],[Numeric, String],[Numeric, String]],
    between:            "between?",
    compact:            [Array],
    to_set:             [Array],
    flatten:            [Array, [Fixnum, nil]],
    length:             [Enumerable],
    max:                [Array],
    member:             "member?",
    member?:            [Enumerable, [Object]],
    empty:              "empty?",
    empty?:             [Enumerable],
    reverse:            [Array],
    slice:              [Array, Fixnum, Fixnum],
    each_slice:         [Array, Fixnum],
    sort:               [Array],
    split:              [String, String],
    uniq:               [Array],
    sum:                [Array],
    transpose:          [Array],
    join:               [Array, String],
    zip:                [Array, [Array, Array, Array]],
    index:              [Array, [Object]],
    product:            [Array, Array],
    first:              [[ActiveRecord::Relation, Enumerable], [nil, Fixnum]],
    last:               [[ActiveRecord::Relation, Enumerable], [nil, Fixnum]],
    intersection:       [Set, Enumerable],
    union:              [Set, Enumerable],

    keys:               [Hash],
    values:             [Hash],
    upcase:             [String],
    downcase:           [String],
    match:              [String, [String], [nil, Fixnum]],

    iso8601:            [DT_TYPES],
    hour:               [DT_TYPES],
    min:                [DT_TYPES+[Array]],
    sec:                [DT_TYPES],
    to_date:            [DT_TYPES+[String]],

    month:              [DT_TYPES],
    day:                [DT_TYPES],
    year:               [DT_TYPES],

    next_month:         [DT_TYPES, [nil, Fixnum]],
    prev_month:         [DT_TYPES, [nil, Fixnum]],

    beginning_of_month: [DT_TYPES],

    end_of_month:       [DT_TYPES],

    next_day:           [DT_TYPES, [nil, Fixnum]],
    prev_day:           [DT_TYPES, [nil, Fixnum]],

    to_i:               [[Numeric, String]],
    to_f:               [[Numeric, String]],
    to_d:               [[Numeric, String]],
    to_s:               [Object],
    to_a:               [Object],
    to_json:            [Object],
    abs:                [Numeric],
    round:              [Numeric, [nil, Integer]],
    ceil:               [Numeric],
  }

  module BaseModule
    class NodeCall < Struct.new(:_e, :engine, :node, :params)
      def evaluate(attr)
        # FIXME: evaluate() modifies params! => need to clone it.
        # This is pretty awful.  NOTE: can't sanitize params as Marty
        # patches NodeCall and modifies params to send _parent_id.
        # This whole thing needs to be redone.
        engine.evaluate(node, attr, params.clone)
      end

      def /(args)
        raise "non-array/string arg to /" unless
          args.is_a?(Array) || args.is_a?(String)

        begin
          case args
          when Array
            engine.eval_to_hash(node, args, params.clone)
          when String
            engine.evaluate(node, args, params.clone)
          end
        rescue => exc
          Delorean::Engine.grok_runtime_exception(exc)
        end
      end

      # FIXME: % should also support string as args
      def %(args)
        raise "non-array arg to %" unless args.is_a?(Array)

        # FIXME: params.clone!!!!
        engine.eval_to_hash(node, args, params.clone)
      end

      # add new arguments, results in a new NodeCall
      def +(args)
        raise "bad arg to %" unless args.is_a?(Hash)

        NodeCall.new(_e, engine, node, params.merge(args))
      end

      def sanitized_params
        BaseClass._sanitize_hash(params)
      end
    end

    class BaseClass
      def self._get_attr(obj, attr, _e)
        # NOTE: should keep this function consistent with _index
        case obj
        when nil
          # FIXME: even Javascript which is superpermissive raises an
          # exception on null getattr.
          return nil
        when ActiveRecord::Base
          return obj.read_attribute(attr) if obj.has_attribute?(attr)
          return obj.send(attr.to_sym) if obj.class.reflections[attr]
        when NodeCall
          return obj.evaluate(attr)
        when Hash
          # FIXME: this implementation doesn't handle something like
          # {}.length.  i.e. length is a whitelisted function, but not
          # an attr. This implementation returns nil instead of 0.
          return obj[attr] if obj.member?(attr)
          return attr.is_a?(String) ? obj[attr.to_sym] : nil
        when Class
          return obj.send((attr + POST).to_sym, _e) if obj < BaseClass
        end

        begin
          return _instance_call(obj, attr, [], _e)
        rescue => exc
          raise InvalidGetAttribute,
          "attr lookup failed: '#{attr}' on <#{obj.class}> #{obj} - #{exc}"
        end
      end

      ######################################################################

      def self._index(obj, args, _e)
        # NOTE: should keep this function consistent with _get_attr
        case obj
        when nil
          # FIXME: even Javascript which is superpermissive raises an
          # exception on null getattr.
          return nil
        when Hash, ActiveRecord::Base, NodeCall, Class
          raise InvalidIndex unless args.length == 1
          _get_attr(obj, args[0], _e)
        when Array, String
          raise InvalidIndex unless args.length <= 2 &&
                                    args[0].is_a?(Fixnum) &&
                                    (args[1].nil? || args[1].is_a?(Fixnum))
          obj[*args]
        else
          raise InvalidIndex
        end
      end

      ######################################################################

      def self._sanitize_hash(_e)
        _e.each_with_object({}) do
          |(k,v), h|
          h[k] = v if k.is_a?(Integer) || k =~ /\A[a-z][A-Za-z0-9_]*\z/
        end
      end

      ######################################################################

      def self._err(*args)
        str = args.map(&:to_s).join(", ")
        raise str
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

      def self._instance_call(obj, method, args, _e)
        begin
          msg = method.to_sym
        rescue NoMethodError
          raise "bad method #{method}"
        end

        # FIXME: this is pretty hacky -- should probably merge
        # RUBY_WHITELIST and SIG mechanisms.
        if obj.is_a?(Class)
          _e[:_engine].parse_check_call_fn(method, args.count, obj)
          return obj.send(msg, *args)
        end

        cls = obj.class
        sig = (cls < Delorean::Model && cls.delorean_instance_methods[msg]) ||
              RUBY_WHITELIST[msg]

        raise "no such method #{method}" unless sig

        # if sig is a string, then method mapped to another name
        return _instance_call(obj, sig, args, _e) if sig.is_a? String

        raise "too many args to #{method}" if args.length>(sig.length-1)

        arglist = [obj] + args

        sig.each_with_index do |s, i|
          s = [s] unless s.is_a?(Array)

          ai = arglist[i]

          raise "bad arg #{i}, method #{method}: #{ai}/#{ai.class} #{s}" unless
            (s.member?(nil) && i>=arglist.length) ||
            s.detect {|sc| sc && ai.class <= sc}
        end

        res = obj.send(msg, *args)
        # FIXME: can't freeze AR relations since then we can't chain
        # calls (e.g. the chaining modifies the relation object.  Not
        # sure what this side-effect means.  Delorean code which
        # perform queries on queries seems to work.
        ActiveRecord::Relation === res ? res : res.freeze
      end

      ######################################################################
    end
  end
end
