require 'pp'

=begin

IMPLEMENTATION

* for each attr, we define a sister class function attr_info.  This
  function tells us the list of other attrs used by the attr.  Also,
  tells us if the attr is a parameter.

  node_attrs tell us the direct attrs.  It doesn't tell us about
  inherited ones.

* Remove type mechanism

  get_sig_type
  initialize_sigmap
  sigmap
  Delorean.str_type
  SigMap.match_call_type

######################################################################

IDEA: how about making the language a lot simpler.  Allow params to
hide attrs and vice-versa.  Treat "nil" as undefined.  Anytime we're
about to return nil, we instead raise undefined error. 

The user can override any attrs, including those that return nil.  We
remove any typing altogether. i.e. no typing for params.  Use a
special notation for nil, e.g. ?.

Do we still need to define the _attr methods?  Since we're not keeping
the parent relationships, this is the only way to determine if an attr
is previsouly defined.

=end

=begin

* What does it mean for a parameter to be redefined?  IS it still a
  parameter?  Can we have defualt values for parameters?  Can deffault
  values be overwritten?  

  -- Parameters are special.  We do not allow them to be overwritten
     with attribute definitions.  But, we can allow defaults and
     overwriting of default values with new param definitions.

	A:
	  integer? a = 123 # default
	B: A
	  integer? a = 456

  -- NOTE: What does it mean if a parameters is used from a parent
     node?  Need to know what happens both in cases where parameter is
     provided and where it is not.

	A:
	  integer? a = 123
	B: A
	  b = A.a + 111

** Let's define params by their implementation.  Like attributes, each
   param will have an associated instance variable for its node.  When
   a node N is called and value V is provided for parameter P, we set
   instance variable associated with P to V.  This is set on the
   nearest ancestor node to N which defines P.  

** Why can't we override params with attribute definitions?
   
######################################################################

** Restrict parameter defaults to constant values.

** Each node either has a set of attr definitions. An attr can be
   defined as a parameter.  Each attr may depend on 0 or more local or
   ancestor attrs.

** To execute a node attr, we pass in a set of parameter values.  For
   each value, the parameter is set on the node and _all_ ancestors
   which define the parameter.

** To implement this, any params refer to the original ancestor which
   defines it.

A:
  integer? param = 123
B: A
  integer? param = 456
  x = A.param
C: B
  integer? param = 789
D: C

class A
  def param; 
    @param || 123
  end
end

class B
  def param; @param || 456; end
  def x; A.param; end
end

=end

require 'delorean/types'

module Delorean
  class SNode < Treetop::Runtime::SyntaxNode
  end

  class Parameter < SNode
    def check(context)
      attr, ptype = i.text_value, t.text_value

      context.model_class t.text_value if
        t.text_value.match(/^[A-Z]/)

      context.define_attr(attr, ptype)
    end

    def rewrite(context)
      ""
    end
  end

  class ParameterDefault < Parameter
  end

  class BaseNode < SNode
    def check(context)
      context.define_node(n.text_value, nil)
    end

    def rewrite(context)
      "class #{n.text_value}"
    end
  end

  class SubNode < SNode
    def check(context)
      context.define_node(n.text_value, p.text_value)
    end

    def rewrite(context)
      "class #{n.text_value} < #{p.text_value}"
    end
  end

  class Formula < SNode
    def check(context)
      # puts '>'*10, i.text_value
      e.check(context)
      context.define_attr(i.text_value, nil)
    end

    def rewrite(context)
      "def self.#{i.text_value}; " + e.rewrite(context) + "; end"
    end
  end

  class Expr < SNode
    def check(context)
      e.check(context)
    end

    def rewrite(context)
      "(" + e.rewrite(context) + ")"
    end
  end

  class UnOp < SNode
    def check(context)
      # puts 'u'*20, op.text_value
      res_t = e.check(context)
      return context.get_sig_type(op.text_value, [res_t])
    end

    def rewrite(context)
      "(" + op.text_value + e.rewrite(context) + ")"
    end
  end

  class BinOp < SNode
    def check(context)
      # puts 'o'*20, op.text_value
      vtype = v.check(context)
      etype = e.check(context)
      return context.get_sig_type(op.text_value, [vtype, etype])
    end

    def rewrite(context)
      "(" + v.rewrite(context) + " " + op.text_value + " " + e.rewrite(context) + ")"
    end
  end

  class Integer < SNode
    def check(context)
      TInteger
    end

    def rewrite(context)
      text_value
    end
  end

  class String < SNode
    def check(context)
      TString
    end

    def rewrite(context)
      text_value # FIXME: not sure about this.  Are the quotes here?
    end
  end

  class Decimal < SNode
    def check(context)
      TDecimal
    end

    def rewrite(context)
      text_value
    end
  end

  class Boolean < SNode
    def check(context)
      TBoolean
    end

    def rewrite(context)
      text_value.downcase
    end
  end

  class Identifier < SNode
    def check(context)
      res = context.call_last_node_attr(text_value)
      # puts '-'*10, [text_value, res].inspect
      res
    end

    def rewrite(context)
      text_value
    end
  end

  class GetAttr < SNode
    def check(context)
      # puts 'A'*30
      itype = i.check(context)
      # puts 'd'*10, ga, ga.text_value.inspect
      attr_list = ga.text_value.split('.')

      attr_list.each { |a|
        itype = context.model_attr_type(itype, ga.text_value)
      }
      return itype
    end

    def rewrite(context)
      text_value
    end
  end

  class Fn < SNode
    def check(context)
      arg_types = defined?(args) ? args.check(context) : []
      # puts 'f'*10, fn, text_value
      # puts 'a'*10, arg_types
      context.get_sig_type(fn.text_value, arg_types)
    end

    def rewrite(context)
      fn.text_value + "(" + (defined?(args) ? args.rewrite(context) : "") + ")"
    end
  end

  class FnArgs < SNode
    def check(context)
      # puts 'ar'*10, context, arg0, text_value

      if defined? args_rest.args
        # puts '.'*10, args_rest.args
        [arg0.check(context)] + args_rest.args.check(context)
      else
        # puts 'u'*20
        [arg0.check(context)]
      end
    end

    def rewrite(context)
      arg0.rewrite(context) +
        (defined?(args_rest.args) ? ", " + args_rest.args.rewrite(context) : "")
    end
  end

  class ModelFn < SNode
    def check(context)
      arg_types = defined?(args) ? args.check(context) : []
      # puts 'm'*10, arg_types.inspect, m.text_value, fn.text_value
      context.model_fn_type(m.text_value, fn.text_value, arg_types)
    end

    def rewrite(context)
      m.text_value + "." + fn.text_value +
        "(" + (defined?(args) ? args.rewrite(context) : "") + ")"
    end
  end

  class IfElse < SNode
    def check(context)
      vtype = v.check(context)
      e1type = e1.check(context)
      e2type = e2.check(context)
      return context.get_sig_type('?:', [vtype, e1type, e2type])
    end

    def rewrite(context)
      "(" + v.rewrite(context) + " ? " +
        e1.rewrite(context) + " : " + e2.rewrite(context) + ")"
    end
  end
end
