require 'pp'

=begin

The following is the list of compile-time checks we perform:

* For any attribute usage, make sure the attribute was previsously
  defiend in current or parent node. Also, perform type check on
  attribute usage.

* For any function call, verify existance of the function.  Also,
  verify number and type of arguments as well as type check for return
  value.  Same needs to be applied to operator usage.  Operators and
  functions may be overloaded. [FIXME: are we going to have a special
  syntax for parameters?]

* For any table function call, verify the existance of given model and
  a class method with the given name.  The function are named and must
  match the function's argument signature.  The return type is also
  defined in the signature of the function.  Class methods can return
  database model instances.

* For any getattr (e.g. a.b.c), the existance of the attribute and its
  type are checked.  For instance, for the expression a.b, a must be a
  database type and must have model attribute "b".  The model type for
  b also defined the type for the expression.

TYPES:

* nil implies undefined.  nil matches all types.

* Base system types are: decimal, integer, string.

* Database types all start with caps and map to the database model of
  the same name.

Implementation:

* As the document is parsed, we generate a class for each node.  Also,
  for every node attribute defined, we define a method on that class
  which returns information about the attribute.

* The context for compilation is the current node class as well as the
  entire module which contains all node classes.

* The context also needs to define the set of system functions as well
  as a way to check for definition of models.

ISSUES:

* Need to be able to handle nil when dealing with DB objects.

* Where can we get node name from?  Perhaps, NAME should be a special
  attribute.

* Should not allow true/false to be redefined.

=end

require 'delorean/types'

module Delorean
  class SNode < Treetop::Runtime::SyntaxNode
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

  class TypedFormula < Formula
    def check(context)
      attr, type = i.text_value, Delorean.str_type(context, t.text_value)

      # puts 'T'*10, attr, type
      res_t = e.check(context)
      raise "type mismatch assigning #{res_t.to_s} to #{type.to_s}" unless
        res_t <= type

      context.define_attr(attr, type)
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
