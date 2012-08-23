require 'pp'

module Delorean
  class SNode < Treetop::Runtime::SyntaxNode
  end

  class Parameter < SNode
    def check(context)
      context.define_attr(i.text_value, {})
    end
    def rewrite(context)
      "class #{context.last_node}; " +
        "def self.#{i.text_value}; self._fetch_param('#{i.text_value}'); end; end;"
    end
  end

  class ParameterDefault < Parameter
    def check(context)
      spec = e.check(context)
      context.define_attr(i.text_value, spec)
    end

    def rewrite(context)
      "class #{context.last_node}; " +
        "def self.#{i.text_value}; self._get_param('#{i.text_value}') || (" +
        e.rewrite(context) + "); end; end;"
    end
  end

  class BaseNode < SNode
    def check(context)
      context.define_node(n.text_value, nil)
    end

    def rewrite(context)
      # nodes are already defined in define_node
      ""
    end
  end

  class SubNode < SNode
    def check(context)
      context.define_node(n.text_value, p.text_value)
    end

    def rewrite(context)
      # nodes are already defined in define_node
      ""
    end
  end

  class Formula < SNode
    def check(context)
      # puts '>'*10, i.text_value
      res = e.check(context)
      context.define_attr(i.text_value, res)
    end

    def rewrite(context)
      "class #{context.last_node}; " +
        "def self.#{i.text_value}; " + e.rewrite(context) + "; end; end;"
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
      e.check(context)
    end

    def rewrite(context)
      "(" + op.text_value + e.rewrite(context) + ")"
    end
  end

  class BinOp < SNode
    def check(context)
      # puts 'o'*20, op.text_value
      vc = v.check(context)
      ec = e.check(context)
      ec.merge(vc)
    end

    def rewrite(context)
      "(" + v.rewrite(context) + " " + op.text_value + " " + e.rewrite(context) + ")"
    end
  end

  class Integer < SNode
    def check(context)
      {}
    end

    def rewrite(context)
      text_value
    end
  end

  class String < SNode
    def check(context)
      {}
    end

    def rewrite(context)
      text_value # FIXME: not sure about this.  Are the quotes here?
    end
  end

  class Decimal < SNode
    def check(context)
      {}
    end

    def rewrite(context)
      text_value
    end
  end

  class Boolean < SNode
    def check(context)
      {}
    end

    def rewrite(context)
      text_value.downcase
    end
  end

  class Identifier < SNode
    def check(context)
      res = context.call_last_node_attr(text_value)
      puts 'c'*10, [text_value, res].inspect
      res
    end

    def rewrite(context)
      text_value
    end
  end

  class NodeGetAttr < SNode
    def check(context)
      context.call_attr(n.text_value, i.text_value)
    end

    def rewrite(context)
      text_value
    end
  end

  class GetAttr < SNode
    def check(context)
      i.check(context)
    end

    def rewrite(context)
      attr_list = ga.text_value.split('.')
      attr_list.inject(i.text_value) {|x, y| "_get_attr(#{x}, '#{y}')"}
    end
  end

  class Fn < SNode
    def check(context)
      res = defined?(args) ? args.check(context) : {}
      puts 'f'*10, fn, text_value
      puts 'a'*10, args, res
      context.check_call_fn(fn.text_value, res.length)
      res
    end

    def rewrite(context)
      fn.text_value + "(" + (defined?(args) ? args.rewrite(context) : "") + ")"
    end
  end

  class FnArgs < SNode
    def check(context, index=0)
      # puts 'ar'*10, context, arg0, text_value

      if defined? args_rest.args
        # puts '.'*10, args_rest.args

        {index => arg0.check(context)}.merge(args_rest.args.check(context, index+1))
      else
        {index => arg0.check(context)}
      end
    end

    def rewrite(context)
      arg0.rewrite(context) +
        (defined?(args_rest.args) ? ", " + args_rest.args.rewrite(context) : "")
    end
  end

  class ModelFn < SNode
    def check(context)
      res = defined?(args) ? args.check(context) : {}
      context.check_call_fn(fn.text_value, res.length, m.text_value)
      return res
    end

    def rewrite(context)
      m.text_value + "." + fn.text_value +
        "(" + (defined?(args) ? args.rewrite(context) : "") + ")"
    end
  end

  class IfElse < SNode
    def check(context)
      vc = v.check(context)
      e1c = e1.check(context)
      e2c = e2.check(context)
      vc.merge(e1c).merge(e2c)
    end

    def rewrite(context)
      "(" + v.rewrite(context) + " ? " +
        e1.rewrite(context) + " : " + e2.rewrite(context) + ")"
    end
  end
end
