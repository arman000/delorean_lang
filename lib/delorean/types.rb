module Delorean
  class TBase
    @name = "base"

    def self.to_str
      @name
    end
  end

  class TString < TBase
    @name = "string"
  end

  class TNumber < TBase
    @name = "number"
  end

  class TInteger < TNumber
    @name = "integer"
  end

  class TDecimal < TNumber
    @name = "decimal"
  end

  class TBoolean < TBase
    @name = "boolean"
  end

  class TModel < TBase
    @name = "model"
  end

  TYPEMAP = [TBase, TString, TNumber, TInteger, TDecimal, TBoolean].inject({}) { |d, t|
    d[t.to_str] = t
    d
  }

  def self.str_type(context, str)
    res = TYPEMAP[str]
    if !res && str.match(/^[A-Z]/)
      # FIXME: this is not correct.  Need to derive a new class from
      # TBase for each model.  We can probably cache these in the
      # context.
      res = context.model_class(str)
    end
    res
  end

  def self.lub(t1, t2)
    return t1 if t1 >= t2
    return t2 if t2 > t1
    TBase
  end

end

