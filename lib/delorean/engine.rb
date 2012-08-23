require 'delorean/base'

module Delorean
  PRE = '_'
  SIG = "_sig"

  class Context
    attr_accessor :m, :last_node

    def initialize
      @m = BaseModule.clone
      @last_node = nil
      @node_attrs = {}
    end

    def define_node(name, pname)
      raise RedefinedError, "#{name} already defined" if
        @m.constants.member? name.to_sym

      raise UndefinedError, "#{pname} not defined yet" if
        pname and !@m.constants.member?(pname.to_sym)

      @m.module_eval("class #{name} < #{pname || 'BaseClass'}; end")
      @last_node = name
      @node_attrs[name] = []
    end

    def call_attr(node_name, attr_name)
      klass = m.module_eval(node_name)

      begin
        klass.send "#{PRE}#{attr_name}".to_sym
      rescue NoMethodError
        raise UndefinedError, "#{attr_name} not defined in #{@node_name}"
      end
    end

    def call_last_node_attr(attr_name)
      raise ParseError, "Not inside a node" unless @last_node
      call_attr(@last_node, attr_name)
    end

    def define_attr(name, spec)
      raise ParseError, "Can't define '#{name}' outside a node" unless
        @last_node

      raise RedefinedError, "Can't redefine '#{name}' in node #{@last_node}" if 
        @node_attrs[@last_node].member? name

      @node_attrs[@last_node] << name
      
      klass = m.module_eval(@last_node)

      klass.class_eval("def self.#{PRE}#{name}; #{spec}; end")
    end

    def model_class(model_name)
      puts 'x'*30, model_name
      begin
        klass = m.module_eval(model_name)
      rescue NoMethodError, NameError
        raise UndefinedError, "Can't find model: #{model_name}"
      end

      raise UndefinedError, "Access to non-model: #{model_name}" unless
        klass.instance_of?(Class) && klass < ActiveRecord::Base 

      klass
    end

    def model_attr_type(klass, attr)
      col = klass.columns_hash[attr]
      raise UndefinedError, "No such attribute #{attr} on #{klass}" unless col
      # puts '.'*30, col.type.to_s, Delorean.str_type(self, col.type.to_s)
      Delorean.str_type(self, col.type.to_s)
    end

    def check_call_fn(fn, argcount, model_name=nil)
      klass = model_name ? model_class(model_name) : (m::BaseClass)

      raise UndefinedFunctionError, "Function #{fn} not found" unless
        klass.methods.member? fn.to_sym

      sig = "#{fn}#{SIG}".upcase.to_sym

      raise UndefinedFunctionError, "Signature #{sig} not found" unless
        klass.constants.member? sig

      min, max = klass.const_get(sig)

      raise BadCallError, "Too many arguments to #{fn} (#{argcount} > #{max})" if
        argcount > max

      raise BadCallError, "Too few arguments to #{fn} (#{argcount} < #{min})" if
        argcount < min
    end

  end

  def self.error(str)
    $stderr.puts str
    raise "ERROR"
  end

  class Attr
    attr_accessor :name, :type, :rhs

    def initialize(type, name, rhs, line_no)
      @name, @rhs = name, rhs
      @type = type if type.length>0

      # check rhs syntax without evaluating it
      begin
        catch(:x) {
          # puts '>'*30, rhs
          eval("throw :x; #{rhs};")
        }
      rescue SyntaxError
        raise ParseError, "syntax error '#{rhs}': #{line_no}"
      end
    end

    def self.parse(line, line_no)
      # puts 'L'*30, line.inspect
      m = line.match(/^\s+(|.+\s+)(#{ATTRNAME_PAT})\s*=(.+)$/)
      Delorean.error "bad attr syntax: #{line_no}" if !m
      new(m[1].strip, m[2].strip, m[3].strip, line_no)
    end
  end

  class Node
    attr_accessor :attr_list, :parent, :name

    def initialize(name, parent, line_no)
      @name, @parent, @attr_list = name, parent, []
    end

    def add_attr(attr)
      @attr_list << attr
    end
  end

  class Engine
    attr_accessor :nodes, :node_names

    def initialize
      @nodes, @node_names = {}, []
    end

    def evaluate(context, node, attr, params={})
      context.m::BaseClass.const_set("PARAMS", params)
      begin
        klass = context.m.module_eval(node)
      rescue NameError
        raise UndefinedNodeError, "node #{node} is undefined"
      end

      klass.send attr.to_sym
    end

    def parse(source)
      context = Context.new
      parser = DeloreanParser.new

      line_no, current_node = 0, nil

      source.each_line do |line|
        line_no += 1

        # skip comments
        next if line.match(/\s*\#/)

        # remove trailing blanks
        line.strip!

        next if line.match(/^\s*$/)

        t = parser.parse(line)

        raise ParseError, "syntax error: #{line_no}" if !t

        t.check(context)

        rew = t.rewrite(context)

        puts '+'*30, rew.inspect

        context.m.module_eval(rew)

      end

     context
    end
  end

end

