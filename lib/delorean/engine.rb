require 'pp'
require 'delorean/base'

module Delorean
  SIG = "_sig"
  MOD = "DELOREAN__"

  class Engine
    attr_accessor :last_node, :module_name, :line_no

    def initialize(module_name)
      @module_name = module_name

      # mapping of module to execution environment (cache + params)
      @param_env_map = {}
      reset
    end

    def reset
      @m, @pm = nil, nil
      @last_node, @node_attrs = nil, {}
      @line_no = 0
    end

    def define_node(name, pname)
      err(RedefinedError, "#{name} already defined") if
        @pm.constants.member? name.to_sym

      err(UndefinedError, "#{pname} not defined yet") if
        pname and !@pm.constants.member?(pname.to_sym)

      code = "class #{name} < #{pname || 'Object'}; end"
      @pm.module_eval(code)

      @last_node = name
      @node_attrs[name] = []
    end

    def call_attr(node_name, attr_name)
      klass = @pm.module_eval(node_name)

      begin
        klass.send("#{attr_name}".to_sym, [])
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
      
      checks = spec.map{ |a|
        n = a.index('.') ? a : (@last_node + "." + a)
        "_x.member?('#{n}') ? raise('#{n}') : #{a}(_x + ['#{n}'])"
      }

      code = "class #{@last_node}; def self.#{name}(_x); #{checks.join(';')}; end; end"

      # pp code

      @pm.module_eval(code)

      begin
        call_attr(@last_node, name)
      rescue RuntimeError
        err(RecursionError, "'#{name}' is recursive")
      end
    end

    def model_class(model_name)
      begin
        klass = @m.module_eval(model_name)
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
      klass = model_name ? model_class(model_name) : (@m::BaseClass)

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

    def parser
      @@parser ||= DeloreanParser.new
    end

    def parse(source)
      raise "can't call parse again without reset" if @m

      @m = BaseModule.clone
      @pm = Module.new

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

        # generate ruby code
        gen = t.rewrite(self)

        # puts gen

        @m.module_eval(gen, "#{MOD}#{module_name}", @line_no)
      end
    end

    ######################################################################
    # Runtime
    ######################################################################

    def evaluate(node, attr, params={})
      evaluate_attrs(node, [attr], params)[0]
    end

    def evaluate_attrs(node, attrs, params={})
      # clone the base engine module if we don't have it for given params
      _env = @param_env_map[params] ||= params

      begin
        klass = @m.module_eval(node)
      rescue NameError
        err(UndefinedNodeError, "node #{node} is undefined")
      end
      attrs.map {|attr| klass.send(attr.to_sym, _env)}
    end

    def parse_runtime_exception(exc)
      # parse out the delorean-related backtrace records
      bt = exc.backtrace.map{ |x|
        x.match(/^#{MOD}(.+?):(\d+)(|:in `(.+)')$/);
        $1 && [$1, $2.to_i, $4]
      }.reject(&:!)

      [exc.message, bt]
    end

    ######################################################################

  end

end
