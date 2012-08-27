require 'delorean/base'

module Delorean
  PRE = '_'
  SIG = "_sig"
  MOD = "DELOREAN__"

  class Engine
    attr_accessor :m, :last_node, :module_name, :line_no

    def initialize(module_name="XXX")
      @m = BaseModule.clone
      @last_node, @node_attrs = nil, {}
      @module_name = module_name
      @line_no = 0
    end

    def define_node(name, pname)
      err(RedefinedError, "#{name} already defined") if
        @m.constants.member? name.to_sym

      err(UndefinedError, "#{pname} not defined yet") if
        pname and !@m.constants.member?(pname.to_sym)

      @m.module_eval("class #{name} < #{pname || 'BaseClass'}; CACHE={}; end")
      @last_node = name
      @node_attrs[name] = []
    end

    def call_attr(node_name, attr_name)
      klass = m.module_eval(node_name)

      begin
        klass.send "#{PRE}#{attr_name}".to_sym
      rescue NoMethodError
        err(UndefinedError, "'#{attr_name}' not defined in #{node_name}")
      end
    end

    def call_last_node_attr(attr_name)
      err(ParseError, "Not inside a node") unless @last_node
      call_attr(@last_node, attr_name)
    end

    def define_attr(name, spec)
      err(ParseError, "Can't define '#{name}' outside a node") unless
        @last_node

      err(RedefinedError, "Can't redefine '#{name}' in node #{@last_node}") if
        @node_attrs[@last_node].member? name

      @node_attrs[@last_node] << name
      
      klass = m.module_eval(@last_node)

      klass.class_eval("def self.#{PRE}#{name}; #{spec}; end")
    end

    def model_class(model_name)
      begin
        klass = m.module_eval(model_name)
      rescue NoMethodError, NameError
        err(UndefinedError, "Can't find model: #{model_name}")
      end

      err(UndefinedError, "Access to non-model: #{model_name}") unless
        klass.instance_of?(Class) && klass < ActiveRecord::Base 

      klass
    end

    def err(exc, msg)
      raise exc.new(msg, @module_name, @line_no)
    end

    def check_call_fn(fn, argcount, model_name=nil)
      klass = model_name ? model_class(model_name) : (m::BaseClass)

      err(UndefinedFunctionError, "Function #{fn} not found") unless
        klass.methods.member? fn.to_sym

      sig = "#{fn}#{SIG}".upcase.to_sym

      err(UndefinedFunctionError, "Signature #{sig} not found") unless
        klass.constants.member? sig

      min, max = klass.const_get(sig)

      err(BadCallError, "Too many arguments to #{fn} (#{argcount} > #{max})") if
        argcount > max

      err(BadCallError, "Too few arguments to #{fn} (#{argcount} < #{min})") if
        argcount < min
    end

    def evaluate(node, attr, params={})
      evaluate_attrs(node, [attr], params)[0]
    end

    def evaluate_attrs(node, attrs, params={})
      m::BaseClass.const_set("PARAMS", params)
      begin
        klass = m.module_eval(node)
      rescue NameError
        err(UndefinedNodeError, "node #{node} is undefined")
      end
      attrs.map {|attr| klass.send attr.to_sym}
    end

    def parse_runtime_exception(exc)
      # parse out the delorean-related backtrace records
      bt = exc.backtrace.map{ |x|
        x.match(/^#{MOD}(.+?):(\d+)(|:in `(.+)')$/);
        $1 && [$1, $2.to_i, $4]
      }.reject(&:!)

      [exc.message, bt]
    end

    def parser
      @@parser ||= DeloreanParser.new
    end

    def parse(source)
      current_node = nil

      source.each_line do |line|
        @line_no += 1

        # skip comments
        next if line.match(/^\s*\#/)

        # remove trailing blanks
        line.strip!

        next if line.length == 0

        t = parser.parse(line)

        err(ParseError, "syntax error") if !t

        t.check(self)

        rew = t.rewrite(self)

        puts rew

        m.module_eval(rew, "#{MOD}#{module_name}", @line_no)
      end
    end
  end
end
