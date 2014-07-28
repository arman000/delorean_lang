require 'delorean/const'
require 'delorean/base'
require 'set'
require 'pp'

module Delorean
  class Engine
    attr_reader :last_node, :module_name, :line_no,
    :comp_set, :pm, :m, :imports, :sset

    def initialize(module_name, sset=nil)
      # name of current module
      @module_name = module_name
      @sset = sset
      reset
    end

    def reset
      @m, @pm = nil, nil
      @last_node, @node_attrs = nil, {}
      @line_no, @multi_no = 0, nil

      # set of comprehension vars
      @comp_set = Set.new

      # set of all params
      @param_set = Set.new

      @imports = {}
    end

    def curr_line
      @multi_no || @line_no
    end

    def parse_import(name)
      err(ParseError, "No script set") unless sset

      err(ParseError, "Module #{name} importing itself") if
        name == module_name

      begin
        @imports[name] = sset.get_engine(name)
      rescue => exc
        err(ImportError, exc.to_s)
      end

      @pm.const_set("#{MOD}#{name}", @imports[name].pm)
    end

    def gen_import(name)
      @imports.merge!(@imports[name].imports)

      @m.const_set("#{MOD}#{name}", @imports[name].m)
    end

    def get_import_engine(name)
      err(ParseError, "#{name} not imported") unless @imports[name]
      @imports[name]
    end

    def is_node_defined(name)
      @pm.constants.member? name.to_sym
    end

    # Check to see if node with given name is defined.  flag tells the
    # method about our expectation.  flag=true means that we make sure
    # that name is defined.  flag=false is the opposite.
    def parse_check_defined_node(name, flag)
      isdef = is_node_defined(name)

      if isdef != flag
        isdef ? err(RedefinedError, "#{name} already defined") :
          err(UndefinedError, "#{name} not defined yet")
      end
    end

    def super_name(pname, mname)
      mname ? "#{MOD}#{mname}::#{pname}" : pname
    end

    def parse_check_defined_mod_node(pname, mname)
      engine = mname ? get_import_engine(mname) : self
      engine.parse_check_defined_node(pname, true)
    end

    def parse_define_node(name, pname, mname=nil)
      parse_check_defined_node(name, false)
      parse_check_defined_mod_node(pname, mname) if pname

      sname = pname ? super_name(pname, mname) : 'Object'

      @pm.module_eval("class #{name} < #{sname}; end")

      # latest defined node
      @last_node = name

      # mapping of node name to list of attrs it defines
      @node_attrs[name] = []
    end

    # Parse-time check to see if attr is available.  If not, error is
    # raised.
    def parse_call_attr(node_name, attr_name)
      return [] if comp_set.member?(attr_name)

      # get the class associated with node
      klass = @pm.module_eval(node_name)

      # puts attr_name, "#{attr_name}#{POST}".to_sym, klass.methods.inspect

      begin
        klass.send("#{attr_name}#{POST}".to_sym, [])
      rescue NoMethodError
        err(UndefinedError, "'#{attr_name}' not defined in #{node_name}")
      end
    end

    # Parse-time check to see if attr is available on current node.
    def parse_call_last_node_attr(attr_name)
      err(ParseError, "Not inside a node") unless @last_node
      parse_call_attr(@last_node, attr_name)
    end

    def parse_define_var(var_name)
      err(RedefinedError,
          "List comprehension can't redefine variable '#{var_name}'") if
        comp_set.member? var_name

      comp_set.add var_name
    end

    def parse_undef_var(var_name)
      err(ParseError, "internal error") unless comp_set.member? var_name
      comp_set.delete var_name
    end

    # parse-time attr definition
    def parse_define_attr(name, spec)
      err(ParseError, "Can't define '#{name}' outside a node") unless
        @last_node

      err(RedefinedError, "Can't redefine '#{name}' in node #{@last_node}") if
        @node_attrs[@last_node].member? name

      @node_attrs[@last_node] << name

      checks = spec.map { |a|
        n = a.index('.') ? a : "#{@last_node}.#{a}"
        "_x.member?('#{n}') ? raise('#{n}') : #{a}#{POST}(_x + ['#{n}'])"
      }.join(';')

      code =
        "class #{@last_node}; def self.#{name}#{POST}(_x); #{checks}; end; end"

      # pp code

      @pm.module_eval(code)

      begin
        parse_call_attr(@last_node, name)
      rescue RuntimeError
        err(RecursionError, "'#{name}' is recursive")
      end
    end

    def parse_define_param(name, spec)
      parse_define_attr(name, spec)
      @param_set.add(name)
    end

    def parse_class(class_name)
      begin
        # need the runtime module here (@m) since we need to
        # introspect methods/attrs.
        klass = @m.module_eval(class_name)
      rescue NoMethodError, NameError
        err(UndefinedError, "Can't find class: #{class_name}")
      end

      err(UndefinedError, "Access to non-class: #{class_name}") unless
        klass.instance_of?(Class)

      klass
    end

    def err(exc, msg)
      raise exc.new(msg, @module_name, curr_line)
    end

    def parse_check_call_fn(fn, argcount, class_name=nil)
      klass = case class_name
              when nil
                @m::BaseClass
              when String
                parse_class(class_name)
              else
                class_name
              end

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

    def generate(t)
      t.check(self)

      begin
        # generate ruby code
        gen = t.rewrite(self)
      rescue RuntimeError => exc
        err(ParseError, "codegen error: " + exc.message)
      end

      # puts gen

      begin
        # evaluate generated code in @m
        @m.module_eval(gen, "#{MOD}#{module_name}", curr_line)
      rescue => exc
        # bad ruby code generated, shoudn't happen
        err(ParseError, "codegen error: " + exc.message)
      end
    end

    def parse(source)
      raise "can't call parse again without reset" if @pm

      # @m module is used at runtime for code evaluation.  @pm module
      # is only used during parsing to check for errors.
      @m, @pm = BaseModule.clone, Module.new

      multi_line, @multi_no = nil, nil

      source.each_line do |line|
        @line_no += 1

        # skip comments
        next if line.match(/^\s*\#/)

        # remove trailing blanks
        line.rstrip!

        next if line.length == 0

        if multi_line
          # if line starts with >4 spaces, assume it's a multline
          # continuation.
          if line =~ /\A {5}/
            multi_line += line
            next
          else
            t = parser.parse(multi_line)
            err(ParseError, "syntax error") unless t

            generate(t)
            multi_line, @multi_no = nil, nil
          end
        end

        t = parser.parse(line)

        if !t
          err(ParseError, "syntax error") unless line =~ /^\s+/

          multi_line = line
          @multi_no = @line_no
        else
          generate(t)
        end
      end

      if multi_line
        t = parser.parse(multi_line)
        err(ParseError, "syntax error") unless t
        generate(t)
      end
    end

    ######################################################################
    # Script development/testing
    ######################################################################

    # enumerate all nodes
    def enumerate_nodes
      SortedSet[* @node_attrs.keys]
    end

    # enumerate qualified list of all attrs
    def enumerate_attrs
      @node_attrs.keys.each_with_object({}) { |node, h|
        h[node] = enumerate_attrs_by_node(node)
      }
    end

    # enumerate qualified list of attrs by node
    def enumerate_attrs_by_node(node)
      raise "bad node" unless node

      begin
        klass = node.is_a?(String) ? @m.module_eval(node) : node
      rescue NameError
        # FIXME: a little hacky.  Should raise an exception.
        return []
      end

      raise "bad node class #{klass}" unless klass.is_a?(Class)

      klass.methods.map(&:to_s).select { |x|
        x.end_with?(POST)
      }.map { |x|
        x.sub(/#{POST}$/, '')
      }
    end

    # enumerate all params
    def enumerate_params
      @param_set
    end

    # enumerate params by a single node
    def enumerate_params_by_node(node)
      attrs = enumerate_attrs_by_node(node)
      Set.new( attrs.select {|a| @param_set.include?(a)} )
    end

    ######################################################################
    # Runtime
    ######################################################################

    def evaluate(node, attr, params={})
      evaluate_attrs(node, [attr], params)[0]
    end

    def eval_to_hash(node, attrs, params={})
      res = evaluate_attrs(node, attrs, params)
      Hash[* attrs.zip(res).flatten(1)]
    end

    def evaluate_attrs(node, attrs, params={})
      raise "bad params" unless params.is_a?(Hash)

      if node.is_a?(Class)
        klass = node
      else
        raise "bad node '#{node}'" unless node =~ /^[A-Z][a-zA-Z0-9_]*$/

        begin
          klass = @m.module_eval(node)
        rescue NameError
          err(UndefinedNodeError, "node #{node} is undefined")
        end
      end

      params[:_engine] = self

      attrs.map { |attr|
        raise "bad attribute '#{attr}'" unless attr =~ /^[a-z][A-Za-z0-9_]*$/
        klass.send("#{attr}#{POST}".to_sym, params)
      }
    end

    def self.grok_runtime_exception(exc)
      # parse out the delorean-related backtrace records
      bt = exc.backtrace.map{ |x|
        x.match(/^#{MOD}(.+?):(\d+)(|:in `(.+)')$/);
        $1 && [$1, $2.to_i, $4.sub(/#{POST}$/, '')]
      }.reject(&:!)

      {"error" => exc.message, "backtrace" => bt}
    end

    ######################################################################

  end
end
