require 'pp'

module Delorean
  class SNode < Treetop::Runtime::SyntaxNode
  end

  class Line < SNode
    def check(context)
      f.check(context)
    end
    def rewrite(context)
      f.rewrite(context)
    end
  end

  class Parameter < SNode
    def check(context)
      context.parse_define_param(i.text_value, [])
    end

    def rewrite(context)
      # Adds a parameter to the current node.  Parameters are
      # implemented as functions (just like attrs).  The environment
      # arg (_e) is a Hash.  _fetch_param() simply looks up the param
      # in _e and raises an error it not found.
      "class #{context.last_node}; " +
        "def self.#{i.text_value}#{POST}(_e); _e['#{i.text_value}'] ||= " +
        "self._fetch_param(_e, '#{i.text_value}'); end; end;"
    end
  end

  class ParameterDefault < Parameter
    def check(context)
      # The check function returns the list of attrs used in the
      # default expression.  This is then used to make check if the
      # attrs are available in the param's context.  NOTE: in a
      # previous implementation, spec used to include attr type
      # information so that we could perform static type checking.
      # This mechanism has been removed.
      spec = e.check(context)
      context.parse_define_param(i.text_value, spec)
    end

    def rewrite(context)
      # Implements default parameters.  It returns the param if it's
      # already defined in the environment (_e).  Otherwise returns
      # the eval of default value expression.
      "class #{context.last_node}; " +
        "def self.#{i.text_value}#{POST}(_e); _e[:#{i.text_value}] ||= " +
        "_e['#{i.text_value}'] || (" + e.rewrite(context) + "); end; end;"
    end
  end

  class BaseNode < SNode
    # defines a base node
    def check(context)
      context.parse_define_node(n.text_value, nil)
    end

    def rewrite(context)
      # Nodes are simply translated to classes.
      "class #{n.text_value} < BaseClass; end"
    end
  end

  class SubNode < SNode
    def check(context)
      context.parse_define_node(n.text_value, p.text_value)
    end

    def rewrite(context)
      # A sub-node (derived node) is just a subclass.
      "class #{n.text_value} < #{p.text_value}; end"
    end
  end

  class Formula < SNode
    def check(context)
      context.parse_define_attr(i.text_value, e.check(context))
    end

    def rewrite(context)
      # an attr is defined as a class function on the node class.
      "class #{context.last_node}; " +
        "def self.#{i.text_value}#{POST}(_e); " +
        "_e['#{context.last_node}.#{i.text_value}'] ||= " +
        e.rewrite(context) + "; end; end;"
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

  # unary operator
  class UnOp < SNode
    def check(context)
      e.check(context)
    end

    def rewrite(context)
      op.text_value + e.rewrite(context)
    end
  end

  class BinOp < SNode
    def check(context)
      vc, ec = v.check(context), e.check(context)
      # returns list of attrs used in RHS and LHS
      ec + vc
    end

    def rewrite(context)
      v.rewrite(context) + " " + op.text_value + " " + e.rewrite(context)
    end
  end

  class Literal < SNode
    def check(context)
      []
    end

    # Delorean literals have same syntax as Ruby
    def rewrite(context)
      text_value
    end
  end

  class Integer < Literal
  end

  class Decimal < Literal
  end

  class Boolean < Literal
  end

  class String < Literal
    def rewrite(context)
      # remove the quotes and requote.  We don't want the likes of #{}
      # evals to just pass through.
      text_value[1..-2].inspect
    end
  end

  class Identifier < SNode
    def check(context)
      context.parse_call_last_node_attr(text_value)
      [text_value]
    end

    def rewrite(context)
      # Identifiers are just attr accesses.  These are translated to
      # class method calls.  POST is used in mangling the attr names.
      # _e is the environment.
      text_value + POST + '(_e)'
    end
  end

  class NodeGetAttr < SNode
    def check(context)
      context.parse_call_attr(n.text_value, i.text_value)
      [text_value]
    end

    def rewrite(context)
      text_value + POST + '(_e)'
    end
  end

  class GetAttr < SNode
    def check(context)
      i.check(context)
    end

    def rewrite(context)
      attr_list = ga.text_value.split('.')
      attr_list.inject(i.rewrite(context)) {|x, y| "_get_attr(#{x}, '#{y}')"}
    end
  end

  class ModelFnGetAttr < SNode
    def check(context)
      mfn.check(context)
    end

    def rewrite(context)
      x = mfn.rewrite(context)
      "_get_attr(#{x}, '#{i.text_value}')"
    end
  end

  class Fn < SNode
    def check(context)
      acount, res =
        defined?(args) ? [args.arg_count, args.check(context)] : [0, []]

      context.parse_check_call_fn(fn.text_value, acount)
      res
    end

    def rewrite(context)
      fn.text_value + "(" + (defined?(args) ? args.rewrite(context) : "") + ")"
    end
  end

  class FnArgs < SNode
    def check(context)
      arg0.check(context) + (defined?(args_rest.args) ?
                             args_rest.args.check(context) : [])
    end

    def rewrite(context)
      arg0.rewrite(context) +
        (defined?(args_rest.args) ? ", " + args_rest.args.rewrite(context) : "")
    end

    def arg_count
      defined?(args_rest.args) ? 1 + args_rest.args.arg_count : 1
    end
  end

  class ModelFn < SNode
    def check(context)
      acount, res =
        defined?(args) ? [args.arg_count, args.check(context)] : [0, []]

      context.parse_check_call_fn(fn.text_value, acount, m.text_value)
      res
    end

    def rewrite(context)
      m.text_value + "." + fn.text_value +
        "(" + (defined?(args) ? args.rewrite(context) : "") + ")"
    end
  end

  class IfElse < SNode
    def check(context)
      vc, e1c, e2c =
        v.check(context), e1.check(context), e2.check(context)
      vc + e1c + e2c
    end

    def rewrite(context)
      "(" + v.rewrite(context) + ") ? (" +
        e1.rewrite(context) + ") : (" + e2.rewrite(context) + ")"
    end
  end
end
