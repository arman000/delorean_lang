# frozen_string_literal: true

module Delorean
  class SNode < Treetop::Runtime::SyntaxNode
  end

  class Line < SNode
    def check(context, *a)
      f.check(context, *a)
    end

    def rewrite(context)
      f.rewrite(context)
    end
  end

  class Parameter < SNode
    def check(context, *)
      context.parse_define_param(i.text_value, [])
    end

    def rewrite(context)
      # Adds a parameter to the current node.  Parameters are
      # implemented as functions (just like attrs).  The environment
      # arg (_e) is a Hash.  To find a param (aname) in node (cname),
      # we first check to see if cname.aname has already been computed
      # in _e.  If not, to compute it we check for the value in _e
      # (i.e. check for aname).  Otherwise, we use the default value
      # if any.
      aname = i.text_value
      cname = context.last_node
      not_found = defined?(e) ? e.rewrite(context) :
        "raise UndefinedParamError, 'undefined parameter #{aname}'"

      <<eos
      class #{cname}
        def self.#{aname}#{POST}(_e)
            _e[self.name+'.#{aname}'] ||= _e.fetch('#{aname}') { #{not_found} }
        end
      end
eos
    end
  end

  class ParameterDefault < Parameter
    def check(context, *)
      # The check function returns the list of attrs used in the
      # default expression.  This is then used to make check if the
      # attrs are available in the param's context.  NOTE: in a
      # previous implementation, spec used to include attr type
      # information so that we could perform static type checking.
      # This mechanism has been removed.
      spec = e.check(context)
      context.parse_define_param(i.text_value, spec)
    end
  end

  class Import < SNode
    def check(context)
      context.parse_import(n.text_value)
    end

    def rewrite(context)
      context.gen_import(n.text_value)
      ''
    end
  end

  class BaseNode < SNode
    # defines a base node
    def check(context, *)
      context.parse_define_node(n.text_value, nil)
    end

    def def_class(context, base_name)
      # Nodes are simply translated to classes.  Define our own
      # self.name() since it's extremely slow in MRI 2.0.
      "class #{n.text_value} < #{base_name}; " \
        "def self.module_name; '#{context.module_name}'; end;" \
        "def self.name; '#{n.text_value}'; end; end"
    end

    def rewrite(context)
      def_class(context, 'BaseClass')
    end
  end

  class SubNode < BaseNode
    def check(context, *)
      mname = mod.m.text_value if defined?(mod.m)
      context.parse_define_node(n.text_value, p.text_value, mname)
    end

    def rewrite(context)
      mname = mod.m.text_value if defined?(mod.m)
      sname = context.super_name(p.text_value, mname)

      # A sub-node (derived node) is just a subclass.
      def_class(context, sname)
    end
  end

  class SubNodeNested < BaseNode
    def check(context, *)
      module_names = mod.m.text_value.split('::')
      node_name = module_names.pop
      mname = module_names.join('::') if module_names.any?

      context.parse_define_node(n.text_value, node_name, mname)
    end

    def rewrite(context)
      module_names = mod.m.text_value.split('::')
      node_name = module_names.pop
      mname = module_names.join('::') if module_names.any?

      sname = context.super_name(node_name, mname)

      # A sub-node (derived node) is just a subclass.
      def_class(context, sname)
    end
  end

  class Formula < SNode
    def check(context, *)
      context.parse_define_attr(i.text_value, e.check(context))
    end

    def rewrite(context)
      dname = [context.module_name, context.last_node, i.text_value].join('.')
      debug = Debug.debug_set.member?(dname)

      # an attr is defined as a class function on the node class.
      "class #{context.last_node}; " \
        "def self.#{i.text_value}#{POST}(_e); " +
        (debug ? '_debug =' : '') +
        "_e[self.name+'.#{i.text_value}'] ||= #{e.rewrite(context)};" +
        (debug ? 'Delorean::Debug.log(_debug); _debug;' : '') +
        'end; end;'
    end
  end

  class Expr < SNode
    def check(context, *)
      e.check(context)
    end

    def rewrite(context)
      "(#{e.rewrite(context)})"
    end
  end

  class ClassText
    attr_reader :text

    def initialize(text)
      @text = text
    end

    def +(other)
      to_s + other
    end

    def to_s
      text
    end
  end

  class NodeAsValue < SNode
    def check(context, *)
      node_name = c.text_value
      mname = mod.m.text_value if defined?(mod.m)
      begin
        context.parse_check_defined_mod_node(node_name, mname)
      rescue UndefinedError, ParseError
        # Node is a non-Delorean ruby class
        context.parse_class(text_value)
      end
      []
    end

    def rewrite(context)
      node_name = c.text_value
      mname = mod.m.text_value if defined?(mod.m)
      begin
        context.parse_check_defined_mod_node(node_name, mname)
        context.super_name(node_name, mname)
      rescue UndefinedError, ParseError
        # FIXME: wrap the class name so Call will be able to tell it
        # apart from a regular value.
        ClassText.new(text_value)
      end
    end
  end

  class NodeAsValueNested < SNode
    def check(context, *)
      module_names = c.text_value.split('::')
      node_name = module_names.pop
      mname = module_names.join('::') if module_names.any?

      begin
        context.parse_check_defined_mod_node(node_name, mname)
      rescue UndefinedError, ParseError
        # Node is a non-Delorean ruby class
        context.parse_class(text_value)
      end
      []
    end

    def rewrite(context)
      module_names = c.text_value.split('::')
      node_name = module_names.pop
      mname = module_names.join('::') if module_names.any?

      begin
        context.parse_check_defined_mod_node(node_name, mname)
        context.super_name(node_name, mname)
      rescue UndefinedError, ParseError
        # FIXME: wrap the class name so Call will be able to tell it
        # apart from a regular value.
        ClassText.new(text_value)
      end
    end
  end

  # unary operator
  class UnOp < SNode
    def check(context, *)
      e.check(context)
    end

    def rewrite(context)
      op.text_value + e.rewrite(context)
    end
  end

  class BinOp < SNode
    def check(context, *)
      vc = v.check(context)
      ec = e.check(context)
      # returns list of attrs used in RHS and LHS
      ec + vc
    end

    def rewrite(context)
      if op.text_value.start_with? 'in'
        "(#{e.rewrite(context)}).member?( #{v.rewrite(context)} )"
      else
        v.rewrite(context) + " #{op.text_value} " + e.rewrite(context)
      end
    end
  end

  # hacky, for backwards compatibility
  class ErrorOp < SNode
    def check(context, *)
      args.text_value == '' ? [] : args.check(context)
    end

    def rewrite(context, *)
      args.text_value != '' ?
        "_err(#{args.rewrite(context)})" :
        'binding.pry; 0'
    end
  end

  class IndexOp < SNode
    def check(context, *)
      args.check(context)
    end

    def rewrite(context, vcode)
      "_index(#{vcode}, [#{args.rewrite(context)}], _e)"
    end
  end

  class Literal < SNode
    def check(_context, *)
      []
    end

    # Delorean literals have same syntax as Ruby
    def rewrite(_context)
      text_value
    end
  end

  # _ is self -- a naive implementation of "self" for now.
  class Self < SNode
    def check(_context, *)
      []
    end

    def rewrite(_context)
      '_sanitize_hash(_e)'
    end
  end

  class Sup < SNode
    def check(_context, *)
      []
    end

    def rewrite(_context)
      'superclass'
    end
  end

  class IString < Literal
    def rewrite(_context)
      # FIXME: hacky to just fail
      raise 'String interpolation not supported' if text_value =~ /\#\{.*\}/

      # FIXME: syntax check?
      text_value
    end
  end

  class DString < Literal
    def rewrite(_context)
      # remove the quotes and requote.  We don't want the likes of #{}
      # evals to just pass through.
      text_value[1..-2].inspect
    end
  end

  class Identifier < SNode
    def check(context, *)
      context.parse_call_last_node_attr(text_value)
      [text_value]
    end

    def rewrite(context)
      # Identifiers are just attr accesses.  These are translated to
      # class method calls.  POST is used in mangling the attr names.
      # _e is the environment.  Comprehension vars (in comp_set) are
      # not passed the env arg.
      arg = context.comp_set.member?(text_value) ? '' : '(_e)'
      text_value + POST + arg
    end
  end

  ######################################################################

  class GetattrExp < SNode
    def check(context, *)
      v.check(context)
      dotted.check(context)
    end

    def rewrite(context)
      vcode = v.rewrite(context)
      dotted.rewrite(context, vcode)
    end
  end

  class Dotted < SNode
    def check(context, *)
      d.check(context)
      d_rest.check(context) unless d_rest.text_value.empty?
      []
    end

    def rewrite(context, vcode)
      dcode = d.rewrite(context, vcode)

      if d_rest.text_value.empty?
        dcode
      else
        d_rest.rewrite(context, dcode)
      end
    end
  end

  class GetAttr < SNode
    def check(_context, *)
      []
    end

    def rewrite(_context, vcode)
      attr = i.text_value
      attr = "'#{attr}'" unless attr =~ /\A[0-9]+\z/
      "_get_attr(#{vcode}, #{attr}, _e)"
    end
  end

  class Call < SNode
    def check(context, *)
      al.text_value.empty? ? [] : al.check(context)
    end

    def rewrite(context, vcode)
      if al.text_value.empty?
        args_str = ''
        arg_count = 0
      else
        args_str = al.rewrite(context)
        arg_count = al.arg_count
      end

      if vcode.is_a?(ClassText)
        # ruby class call
        class_name = vcode.text
        context.parse_check_call_fn(i.text_value, arg_count, class_name)
        "#{class_name}.#{i.text_value}(#{args_str})"
      else
        "_instance_call(#{vcode}, '#{i.text_value}', [#{args_str}], _e)"
      end
    end
  end

  class NodeCall < SNode
    def check(context, *)
      al.text_value.empty? ? [] : al.check(context)
    end

    def rewrite(context, node_name)
      var = "_h#{context.hcount}"
      res = al.text_value.empty? ? '' : al.rewrite(context, var)
      "(#{var}={}; #{res}; _node_call(#{node_name}, _e, #{var}))"
    end
  end

  ######################################################################

  class ExpGetAttr < SNode
    def check(context, *)
      v.check(context)
    end

    def rewrite(context)
      attrs = ga.text_value.split('.')

      # If ga.text_value is not "", then we need to drop the 1st
      # element since it'll be "".
      attrs.shift

      attrs.inject(v.rewrite(context)) { |x, y| "_get_attr(#{x}, '#{y}', _e)" }
    end
  end

  class FnArgs < SNode
    def check(context, *)
      [
        arg0.check(context),
        (args_rest.args.check(context) if
          defined?(args_rest.args) && !args_rest.args.text_value.empty?)
      ].compact.sum
    end

    def rewrite(context)
      rest = ', ' + args_rest.args.rewrite(context) if
        defined?(args_rest.args) && !args_rest.args.text_value.empty?

      [arg0.rewrite(context), rest].compact.sum
    end

    def arg_count
      defined?(args_rest.args) && !args_rest.args.text_value.empty? ?
        1 + args_rest.args.arg_count : 1
    end
  end

  class IfElse < SNode
    def check(context, *)
      vc = v.check(context)
      e1c = e1.check(context)
      e2c = e2.check(context)
      vc + e1c + e2c
    end

    def rewrite(context)
      "(#{v.rewrite(context)}) ? (#{e1.rewrite(context)}) :
       (#{e2.rewrite(context)})"
    end
  end

  class ListExpr < SNode
    def check(context, *)
      defined?(args) ? args.check(context) : []
    end

    def rewrite(context)
      '[' + (defined?(args) ? args.rewrite(context) : '') + ']'
    end
  end

  class UnpackArgs < SNode
    def check(context, *)
      [arg0.text_value] +
        (defined?(args_rest.args) && !args_rest.args.text_value.empty? ?
         args_rest.args.check(context) : [])
    end

    def rewrite(context)
      arg0.rewrite(context) +
        (defined?(args_rest.args) && !args_rest.args.text_value.empty? ?
         ', ' + args_rest.args.rewrite(context) : '')
    end
  end

  class ListComprehension < SNode
    def check(context, *)
      unpack_vars = args.check(context)
      e1c = e1.check(context)
      unpack_vars.each { |vname| context.parse_define_var(vname) }

      # need to check e2/e3 in a context where the comprehension var
      # is defined.
      e2c = e2.check(context)
      e3c = defined?(ifexp.e3) ? ifexp.e3.check(context) : []

      unpack_vars.each do |vname|
        context.parse_undef_var(vname)
        e2c.delete(vname)
        e3c.delete(vname)
      end

      e1c + e2c + e3c
    end

    def rewrite(context)
      res = ["(#{e1.rewrite(context)})"]
      unpack_vars = args.check(context)
      unpack_vars.each { |vname| context.parse_define_var(vname) }
      args_str = args.rewrite(context)

      res << ".select{|#{args_str}|(#{ifexp.e3.rewrite(context)})}" if
        defined?(ifexp.e3)
      res << ".map{|#{args_str}| (#{e2.rewrite(context)}) }"
      unpack_vars.each { |vname| context.parse_undef_var(vname) }
      res.sum
    end
  end

  class SetExpr < ListExpr
    def rewrite(context)
      "Set#{super}"
    end
  end

  class SetComprehension < ListComprehension
    def rewrite(context)
      "Set[*#{super}]"
    end
  end

  class HashComprehension < SNode
    # used in generating unique hash names
    @@comp_count = 0

    def check(context, *)
      unpack_vars = args.check(context)
      e1c = e1.check(context)
      unpack_vars.each { |vname| context.parse_define_var(vname) }

      # need to check el/er/ei in a context where the comprehension var
      # is defined.
      elc = el.check(context)
      erc = er.check(context)
      eic = defined?(ifexp.ei) ? ifexp.ei.check(context) : []

      unpack_vars.each do |vname|
        context.parse_undef_var(vname)
        elc.delete(vname)
        erc.delete(vname)
        eic.delete(vname)
      end
      e1c + elc + erc + eic
    end

    def rewrite(context)
      res = ["(#{e1.rewrite(context)})"]
      unpack_vars = args.check(context)
      unpack_vars.each { |vname| context.parse_define_var(vname) }
      args_str = args.rewrite(context)

      hid = @@comp_count += 1

      res << ".select{|#{args_str}| (#{ifexp.ei.rewrite(context)}) }" if
        defined?(ifexp.ei)

      unpack_str = unpack_vars.count > 1 ? "(#{args_str})" : args_str

      res << ".each_with_object({}){|#{unpack_str}, _h#{hid}| " \
             "_h#{hid}[#{el.rewrite(context)}]=(#{er.rewrite(context)})}"

      unpack_vars.each { |vname| context.parse_undef_var(vname) }
      res.sum
    end
  end

  class HashExpr < SNode
    def check(context, *)
      defined?(args) ? args.check(context) : []
    end

    def rewrite(context)
      return '{}' unless defined?(args)

      var = "_h#{context.hcount}"
      "(#{var}={}; " + args.rewrite(context, var) + "; #{var})"
    end
  end

  class KwArgs < SNode
    def check(context, *)
      [
        arg0.check(context),
        (ifexp.e3.check(context) if defined?(ifexp.e3)),
        (args_rest.al.check(context) if
          defined?(args_rest.al) && !args_rest.al.empty?)
      ].compact.sum
    end

    def rewrite(context, var, i = 0)
      arg0_rw = arg0.rewrite(context)

      if defined?(splat)
        res = "#{var}.merge!(#{arg0_rw})"
      else
        k_rw = defined?(k.i) ? "'#{k.i.text_value}'" : i.to_s
        res = "#{var}[#{k_rw}]=(#{arg0_rw})"
        i += 1 unless defined?(k.i)
      end

      res += " if (#{ifexp.e3.rewrite(context)})" if defined?(ifexp.e3)
      res += ';'
      res += args_rest.al.rewrite(context, var, i) if
        defined?(args_rest.al) && !args_rest.al.text_value.empty?
      res
    end
  end

  class HashArgs < SNode
    def check(context, *)
      [
        e0.check(context),
        (e1.check(context) unless defined?(splat)),
        (ifexp.e3.check(context) if defined?(ifexp.e3)),
        (args_rest.al.check(context) if
          defined?(args_rest.al) && !args_rest.al.empty?),
      ].compact.sum
    end

    def rewrite(context, var)
      res = if defined?(splat)
              "#{var}.merge!(#{e0.rewrite(context)})"
            else
              "#{var}[#{e0.rewrite(context)}]=(#{e1.rewrite(context)})"
            end
      res += " if (#{ifexp.e3.rewrite(context)})" if defined?(ifexp.e3)
      res += ';'
      res += args_rest.al.rewrite(context, var) if
        defined?(args_rest.al) && !args_rest.al.text_value.empty?
      res
    end
  end
end
