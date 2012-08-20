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

      @m.module_eval("class #{name} < #{pname || Object}; end")
      @last_node = name
      @node_attrs[name] = []
    end

    def call_attr(klass, name)
      klass.send "#{PRE}#{name}".to_sym
    end

    def call_last_node_attr(name)
      raise ParseError, "Not inside a node" unless @last_node

      klass = m.module_eval(@last_node)
      begin
        call_attr(klass, name)
      rescue NoMethodError
        raise UndefinedError, "#{name} not defined in #{@last_node}"
      end
    end

    def define_attr(name, ptype=nil)
      raise ParseError, "Can't define '#{name}' outside a node" unless
        @last_node

      raise RedefinedError, "Can't redefine '#{name}' in node #{@last_node}" if 
        @node_attrs[@last_node].member? name

      @node_attrs[@last_node] << name
      
      klass = m.module_eval(@last_node)

      begin
        optype = call_attr(klass, name)
      rescue NoMethodError
        optype = ptype
      end

      raise OverrideError, "Invalid override of '#{name}'" unless
        ptype == optype

      klass.class_eval("def self.#{PRE}#{name}; #{ptype}; end")
    end

    # FIXME: need to be able to support Node.attr access.  Perhaps, we
    # need a 'node' type?  Need to define Node.name attribute as a
    # string by default so that it can be used in models.

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

    def model_fn_type(model_name, fn, arg_types)
      klass = model_class(model_name)
      methods = klass.methods

      raise "function #{model_name}.#{fn} not found" unless
        methods.member? fn.to_sym

      raise "Signature #{model_name}.#{fn}#{SIG} not found" unless
        methods.member? "#{fn}#{SIG}".to_sym
      
      args, res_type = klass.send "#{fn}#{SIG}".to_sym

      args_t = args.map { |a| Delorean.str_type(self, a) }
      res_t  = Delorean.str_type(self, res_type)

      raise "Incorrect signature #{arg_types} when calling #{model_name}.#{fn}" unless
        SigMap.match_call_type(args_t, arg_types)

      # puts 'r'*30, res_t.inspect

      return res_t
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

    def materialize_attr(klass, attr)
      klass.class_eval("def self.#{attr.name}; #{attr.rhs}; end")
    end

    def materialize
      @node_names.each { |name|
        node = @nodes[name]
        EvalModule.module_eval("class #{node.name} < #{node.parent || Object}; end")
        node.attr_list.each { |attr|
          materialize_attr(eval("EvalModule::#{node.name}"), attr)
        }
      }
    end

    def node_attr_list(name)
      cname = name
      methods = []

      while cname do 
        node = @nodes[cname]
        methods << node.attr_list.reverse.map(&:name)
        cname = node.parent
      end
      
      # Assumes that order of the list is not changed by uniq
      methods = methods.flatten.uniq
    end

    def evaluate(name, args=[])
      # dup of class to evaluate.  Its methods may be modified with the
      # args passed in.
      klass = eval("EvalModule::#{name}").dup
      eval("#{name} = klass")
      methods = self.node_attr_list(name)

      # puts 'E'*10, args.inspect

      args.each{ |arg|
        materialize_attr(klass, Attr.parse(" " + arg, "args"))
      }

      methods.inject({}) { |m, method|
        m[method] = klass.send method.to_sym
        m
      }
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

        puts '+'*30, t.rewrite(context)

        # m = line.match(/^(#{NODENAME_PAT})\s*:\s*(|#{NODENAME_PAT})\s*$/)

        # if m
        #   lhs, rhs = m[1], m[2]

        #   rhs = nil if rhs and rhs.length<1

        #   current_node = Node.new(lhs, rhs, line_no)

        #   Delorean.error "can't redefine node #{name}: #{line_no}" if
        #     @nodes.key?(current_node.name)

        #   parent, name = current_node.parent, current_node.name
        #   Delorean.error "no parent node #{parent}: #{line_no}" if
        #     parent && !@nodes.key?(parent)

        #   @nodes[name] = current_node
        #   @node_names << name
        # else
        #   Delorean.error "not in node: #{line_no}" if !current_node
        #   current_node.add_attr Attr.parse(line, line_no)
        # end
      end

     context
    end
  end

end

