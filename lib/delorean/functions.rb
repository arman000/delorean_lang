require 'delorean/types'

module Delorean
  class FuncDef
    attr_accessor :signature, :restype

    def initialize(signature, restype)
      @signature = signature
      @restype = restype

      if signature.instance_of? Range
        raise "bad signature" if
          signature.min != signature.max || !(signature.min < TBase)
      elsif !signature.instance_of? Array
        raise "Bad signature. Expected array."
      else
        signature.each { |s|
          raise "bad signature item #{s}" if !(s<=TBase)
        }
      end
    end
  end

  class FuncGroup
    def initialize
      @fmap = {}
    end

    def add_def(name, signature, restype)
      @fmap[name] ||= []
      @fmap[name] << FuncDef.new(signature, restype)
    end
  end

  # introspection for DB types: Rate.columns_hash['id']

  OPFUNCS = {
    '?:' =>
    FuncDef.new([TBoolean, TBase, TBase], lambda {|b, e1, e2| Delorean.lub(e1, e2)}),

    '+' =>
    FuncDef.new([TString, TString], TString),

    ['+', '-', '*', '/'] =>
    FuncDef.new([TNumber, TNumber], lambda {|x, y| (x == y) ? x : TDecimal}),
    
    "!" =>
    FuncDef.new([TBoolean], TBoolean),

    ['&&', '||'] =>
    FuncDef.new([TBoolean, TBoolean], TBoolean),

    ['>=', '<=', '>', '<'] =>
    [
     FuncDef.new([TNumber, TNumber], TBoolean),
     FuncDef.new([TString, TString], TBoolean),
    ],

    ['==', '!='] =>
    [
     FuncDef.new([TString, TString], TBoolean),
     FuncDef.new([TNumber, TNumber], TBoolean),
     FuncDef.new([TBoolean, TBoolean], TBoolean),
    ],

    "-" =>
    FuncDef.new([TNumber], lambda {|x| x}),
  }

  class SigMap
    attr_accessor :map # FIXME: for debugging

    def initialize
      @map = {}
    end

    def add_op_map(op, fdef)
      @map[op] ||= {}

      (fdef.instance_of?(Array) ? fdef : [fdef]).each {|f|
        @map[op][f.signature] = f.restype
      }
    end

    def add_map(m)
      m.each { |k, v|
        (k.instance_of?(Array) ? k : [k]).each {|op| add_op_map(op, v) }
      }
    end

    def self.match_call_type(sl, signature)
      if sl.instance_of? Range
        rtype = sl.min
        return signature.count {|s| !(rtype <= s)} <= 0
      end

      return (sl.length == signature.length) &&
        signature.each_with_index.count { |st, i| !(st <= sl[i]) } <= 0
    end

    def get_type2(op, signature)
      sigs = @map[op]
      raise "untyped op: #{op}" if !sigs

      return sigs[signature] if sigs[signature]

      sigs.each { |sl, type|
        return type if SigMap.match_call_type(sl, signature)
      }

      raise "Invalid argument signature #{signature} to '#{op}'"
    end

    # def get_type2(op, signature)
    #   sigs = @map[op]
    #   raise "untyped op: #{op}" if !sigs

    #   return sigs[signature] if sigs[signature]

    #   sigs.each { |sl, type|
    #     if sl.instance_of? Range
    #       rtype = sl.min
    #       return type unless signature.count {|s| !(rtype <= s)} > 0
    #     elsif sl.length == signature.length
    #       # puts 'x'*10, signature.each_with_index.collect { |st, i| st <= sl[i] }

    #       return type unless signature.each_with_index.count {
    #         |st, i| !(st <= sl[i]) } > 0
    #     end
    #   }

    #   raise "Invalid argument signature #{signature} to '#{op}'"
    # end

    def get_type(op, signature)
      t = get_type2(op, signature)
      return t if !t.instance_of?(Proc)
      signature.instance_of?(Array) ? t.call(*signature) : t.call(signature)
    end
  end
end
