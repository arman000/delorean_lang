require 'active_support/time'
require 'active_record'
require 'bigdecimal'
require 'delorean/cache'

module Delorean

  ::Delorean::Cache.adapter = ::Delorean::Cache::Adapters::RubyCache.new(size_per_class: 1000)

  TI_TYPES   = [Time, ActiveSupport::TimeWithZone]
  DT_TYPES   = [Date] + TI_TYPES
  NUM_OR_STR = [Numeric, String]
  NUM_OR_NIL = [nil, Integer]

  # FIXME: the whitelist is quite hacky.  It's currently difficult to
  # override it.  A user will likely want to directly modify this
  # hash.  The whole whitelist mechanism should be eventually
  # rethought.
  RUBY_WHITELIST = {
    # FIXME: hack -- Relation.attributes currently implemented in marty
    attributes:         [[ActiveRecord::Base, ActiveRecord::Relation]],
    between?:           [NUM_OR_STR, NUM_OR_STR, NUM_OR_STR],
    between:            "between?",
    compact:            [[Array, Hash]],
    to_set:             [Array],
    flatten:            [Array, NUM_OR_NIL],
    length:             [[String, Enumerable]],
    max:                [Array],
    member:             "member?",
    member?:            [Enumerable, [Object]],
    empty:              "empty?",
    empty?:             [Enumerable],
    except:             [Hash, String] + [[nil, String]]*9,
    reverse:            [Array],
    slice:              [Array, Integer, Integer],
    each_slice:         [Array, Integer],
    sort:               [Array],
    split:              [String, String],
    uniq:               [Array],
    sum:                [Array],
    transpose:          [Array],
    join:               [Array, String],
    zip:                [Array, Array, [Array, nil], [Array, nil]],
    index:              [Array, [Object]],
    product:            [Array, Array],
    first:              [[ActiveRecord::Relation, Enumerable], NUM_OR_NIL],
    last:               [[ActiveRecord::Relation, Enumerable], NUM_OR_NIL],
    intersection:       [Set, Enumerable],
    union:              [Set, Enumerable],

    keys:               [Hash],
    values:             [Hash],
    fetch:              [Hash, Object, [Object]],
    upcase:             [String],
    downcase:           [String],
    match:              [String, [String], NUM_OR_NIL],

    iso8601:            [DT_TYPES],
    hour:               [DT_TYPES],
    min:                [DT_TYPES+[Array]],
    sec:                [DT_TYPES],
    to_date:            [DT_TYPES+[String]],
    to_time:            [DT_TYPES+[String]],

    month:              [DT_TYPES],
    day:                [DT_TYPES],
    year:               [DT_TYPES],

    next_month:         [DT_TYPES, NUM_OR_NIL],
    prev_month:         [DT_TYPES, NUM_OR_NIL],

    beginning_of_month: [DT_TYPES],
    end_of_month:       [DT_TYPES],

    next_day:           [DT_TYPES, NUM_OR_NIL],
    prev_day:           [DT_TYPES, NUM_OR_NIL],

    to_i:               [NUM_OR_STR + TI_TYPES],
    to_f:               [NUM_OR_STR + TI_TYPES],
    to_d:               [NUM_OR_STR],
    to_s:               [Object],
    to_a:               [Object],
    to_json:            [Object],
    abs:                [Numeric],
    round:              [Numeric, [nil, Integer]],
    ceil:               [Numeric],
    floor:              [Numeric],
    truncate:           [Numeric, [nil, Integer]],
  }

  module BaseModule
    # _e is used by Marty promise_jobs to pass promise-related
    # information
    class NodeCall < Struct.new(:_e, :engine, :node, :params)
      def cloned_params
        # FIXME: evaluate() modifies params! => need to clone it.
        # This is pretty awful.  NOTE: can't sanitize params as Marty
        # patches NodeCall and modifies params to send _parent_id.
        # This whole thing needs to be redone.
        @cp ||= Hash[params]
      end

      def evaluate(attr)
        engine.evaluate(node, attr, cloned_params)
      end

      def /(args)
        begin
          case args
          when Array
            engine.eval_to_hash(node, args, cloned_params)
          when String
            self.evaluate(args)
          else
            raise "non-array/string arg to /"
          end
        rescue => exc
          Delorean::Engine.grok_runtime_exception(exc)
        end
      end

      # FIXME: % should also support string as args
      def %(args)
        raise "non-array arg to %" unless args.is_a?(Array)

        engine.eval_to_hash(node, args, cloned_params)
      end

      # add new arguments, results in a new NodeCall
      def +(args)
        raise "bad arg to %" unless args.is_a?(Hash)

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
        if obj.instance_of?(Hash)
          # FIXME: this implementation doesn't handle something like
          # {}.length.  i.e. length is a whitelisted function, but not
          # an attr. This implementation returns nil instead of 0.
          return obj[attr] if obj.member?(attr)
          return attr.is_a?(String) ? obj[attr.to_sym] : nil
        end

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
        when Hash, NodeCall, Class, OpenStruct
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
        sig = RUBY_WHITELIST[msg]

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

        obj.send(msg, *args)
      end

      ######################################################################
    end
  end
end
