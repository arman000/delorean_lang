require 'pp'
require 'delorean/base'

module Delorean
  SIG = "_sig"
  MOD = "DELOREAN__"
  POST = "__D"

  class Engine
    attr_accessor :last_node, :module_name, :line_no, :param_set

    def initialize(module_name)
      # name of current module
      @module_name = module_name

      # mapping of module to execution environment (cache + params)
      # FIXME: is this really being used?  I don't think this will
      # work properly if we have different default values specified
      # for a param on different nodes and we evaluate attrs on those
      # nodes with the same engine.
      @param_env_map = {}
      reset
    end

    def reset
      @m, @pm = nil, nil
      @last_node, @node_attrs = nil, {}
      @line_no = 0

      # set of all params
      @param_set = Set.new
    end

    def define_node(name, pname)
      err(RedefinedError, "#{name} already defined") if
        @pm.constants.member? name.to_sym

      err(UndefinedError, "#{pname} not defined yet") if
        pname and !@pm.constants.member?(pname.to_sym)

      code = "class #{name} < #{pname || 'Object'}; end"
      @pm.module_eval(code)

      # latest defined node
      @last_node = name
      # mapping of node name to list of attrs it defines
      @node_attrs[name] = []
    end

    def call_attr(node_name, attr_name)
      # get the class associated with node
      klass = @pm.module_eval(node_name)

      # puts attr_name, "#{attr_name}#{POST}".to_sym, klass.methods.inspect

      begin
        klass.send("#{attr_name}#{POST}".to_sym, [])
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
        "_x.member?('#{n}') ? raise('#{n}') : #{a}#{POST}(_x + ['#{n}'])"
      }.join(';')

      code = "class #{@last_node}; def self.#{name}#{POST}(_x); #{checks}; end; end"

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

      # signature methods must be named FUNCTION_NAME_SIG
      sig = "#{fn}#{SIG}".upcase.to_sym

      err(UndefinedFunctionError, "Signature #{sig} not found") unless
        klass.constants.member? sig

      min, max = klass.const_get(sig)

      err(BadCallError, "Too many args to #{fn} (#{argcount} > #{max})") if
        argcount > max

      err(BadCallError, "Too few args to #{fn} (#{argcount} < #{min})") if
        argcount < min
    end

    def parser
      @@parser ||= DeloreanParser.new
    end

    def parse(source)
      raise "can't call parse again without reset" if @pm

      # @m module is used at runtime for code evaluation.  @pm module
      # is only used during parsing to check for errors.
      @m, @pm = BaseModule.clone, Module.new

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

        # pp gen

        begin
          # evaluate generated code in @m
          @m.module_eval(gen, "#{MOD}#{module_name}", @line_no)
        rescue => exc
          # bad ruby code generated, shoudn't happen
          err(ParseError, "codegen error: " + exc.message)
        end
      end
    end

    ######################################################################
    # Script development/testing
    ######################################################################

    # enumerate qualified list of all attrs.
    def enumerate_attrs
      @node_attrs.keys.inject({}) { |h, n|
        klass = @m.module_eval(n)
        h[n] = klass.methods.map(&:to_s).select {|x| x.end_with?(POST)}.map {|x|
          x.sub(/#{POST}$/, '')
        }
        h
      }
    end

    def enumerate_params
      @param_set
    end

    ######################################################################
    # Runtime
    ######################################################################

    def evaluate(node, attr, params={})
      evaluate_attrs(node, [attr], params)[0]
    end

    def evaluate_attrs(node, attrs, params={})
      _env = @param_env_map[params] ||= params

      raise "bad node '#{node}'" unless node.match(/^[A-Z][A-Za-z0-9]*$/)

      begin
        klass = @m.module_eval(node)
      rescue NameError
        err(UndefinedNodeError, "node #{node} is undefined")
      end

      attrs.map {|attr|
        raise "bad attribute '#{attr}'" unless attr.match(/^[a-z][A-Za-z0-9_]*$/)
        klass.send("#{attr}#{POST}".to_sym, _env)
      }
    end

    def parse_runtime_exception(exc)
      # parse out the delorean-related backtrace records
      bt = exc.backtrace.map{ |x|
        x.match(/^#{MOD}(.+?):(\d+)(|:in `(.+)')$/);
        $1 && [$1, $2.to_i, $4.sub(/#{POST}$/, '')]
      }.reject(&:!)

      [exc.message, bt]
    end

    ######################################################################

  end

end
