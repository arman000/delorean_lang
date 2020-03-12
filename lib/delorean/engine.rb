# frozen_string_literal: true

require 'delorean/const'
require 'delorean/base'
require 'set'
require 'pp'

module Delorean
  class Engine
    attr_reader :last_node, :module_name, :line_no,
                :comp_set, :pm, :m, :imports, :sset

    def initialize(module_name, sset = nil)
      # name of current module
      @module_name = module_name
      @sset = sset
      reset
    end

    def reset
      @m = nil
      @pm = nil
      @last_node = nil
      @node_attrs = {}
      @line_no = 0
      @multi_no = nil

      # set of comprehension vars
      @comp_set = Set.new

      # set of all params
      @param_set = Set.new

      @imports = {}

      @hcount = 0
    end

    # used in counting literal hashes
    def hcount
      @hcount += 1
    end

    def curr_line
      @multi_no || @line_no
    end

    def parse_import(name)
      err(ParseError, 'No script set') unless sset

      err(ParseError, "Module #{name} importing itself") if
        name == module_name

      begin
        @imports[name] = sset.get_engine(name)
      rescue StandardError => exc
        err(ImportError, exc.to_s)
      end

      @pm.const_set("#{MOD}#{name.gsub('::', '__')}", @imports[name].pm)
    end

    def gen_import(name)
      @imports.merge!(@imports[name].imports)

      @m.const_set("#{MOD}#{name.gsub('::', '__')}", @imports[name].m)
    end

    def get_import_engine(name)
      err(ParseError, "#{name} not imported") unless @imports[name]
      @imports[name]
    end

    def node_defined?(name)
      @pm.constants.member? name.to_sym
    end

    # Check to see if node with given name is defined.  flag tells the
    # method about our expectation.  flag=true means that we make sure
    # that name is defined.  flag=false is the opposite.
    def parse_check_defined_node(name, flag)
      isdef = node_defined?(name)

      if isdef != flag
        isdef ? err(RedefinedError, "#{name} already defined") :
          err(UndefinedError, "#{name} not defined yet")
      end
    end

    def super_name(pname, mname)
      mname ? "#{MOD}#{mname.gsub('::', '__')}::#{pname}" : pname
    end

    def parse_check_defined_mod_node(pname, mname)
      engine = mname ? get_import_engine(mname) : self
      engine.parse_check_defined_node(pname, true)
    end

    def parse_define_node(name, pname, mname = nil)
      parse_check_defined_node(name, false)
      parse_check_defined_mod_node(pname, mname) if pname

      sname = pname ? super_name(pname, mname) : 'Object'

      @pm.module_eval <<-RUBY, __FILE__, __LINE__ + 1
        class #{name} < #{sname}; end
      RUBY

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
      err(ParseError, 'Not inside a node') unless @last_node
      parse_call_attr(@last_node, attr_name)
    end

    def parse_define_var(var_name)
      if comp_set.member? var_name
        err(RedefinedError,
            "List comprehension can't redefine variable '#{var_name}'")
      end

      comp_set.add var_name
    end

    def parse_undef_var(var_name)
      err(ParseError, 'internal error') unless comp_set.member? var_name
      comp_set.delete var_name
    end

    # parse-time attr definition
    def parse_define_attr(name, spec)
      err(ParseError, "Can't define '#{name}' outside a node") unless
        @last_node

      err(RedefinedError, "Can't redefine '#{name}' in node #{@last_node}") if
        @node_attrs[@last_node].member? name

      @node_attrs[@last_node] << name

      checks = spec.map do |a|
        n = a.index('.') ? a : "#{@last_node}.#{a}"
        "_x.member?('#{n}') ? raise('#{n}') : #{a}#{POST}(_x + ['#{n}'])"
      end.join(';')

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

      return klass if klass.instance_of?(Class) || klass.instance_of?(Module)

      err(UndefinedError, "Access to non-class/module: #{class_name}")
    end

    def err(exc, msg)
      raise exc.new(msg, @module_name, curr_line)
    end

    def parse_check_call_fn(fn, _argcount, class_name = nil)
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
    end

    def parser
      @@parser ||= DeloreanParser.new
    end

    def closing_bracket?(line)
      stripped = line.strip

      return true if stripped == ']'
      return true if stripped == ')'
      return true if stripped == '}'

      false
    end

    def generate(t)
      t.check(self)

      begin
        # generate ruby code
        gen = t.rewrite(self)
      rescue RuntimeError => exc
        err(ParseError, 'codegen error: ' + exc.message)
      end

      # puts gen

      begin
        # evaluate generated code in @m
        @m.module_eval(gen, "#{MOD}#{module_name}", curr_line)
      rescue StandardError => exc
        # bad ruby code generated, shoudn't happen
        err(ParseError, 'codegen error: ' + exc.message)
      end
    end

    def parse(source)
      raise "can't call parse again without reset" if @pm

      # @m module is used at runtime for code evaluation.  @pm module
      # is only used during parsing to check for errors.
      @m = BaseModule.clone
      @pm = Module.new

      multi_line = nil
      @multi_no = nil

      lines = source.each_line.to_a

      lines.each_with_index do |line, index|
        @line_no += 1

        # skip comments
        next if /^\s*\#/.match?(line)

        # remove trailing blanks
        line.rstrip!

        next if line.empty?

        if multi_line
          # if line starts with >4 spaces, assume it's a multline
          # continuation.
          if /\A {5}/.match?(line) || closing_bracket?(line)
            multi_line += line
            next
          else
            t = parser.parse(multi_line)
            err(ParseError, 'syntax error') unless t

            generate(t)
            multi_line = nil
            @multi_no = nil
          end
        end

        # Initially Delorean code is parsed by single line.
        # If line can not be parsed as valid Delorean expressions, parser
        # would combine it with the following lines that are indented by more
        # than 4 spaces and attempt to parse it again.

        # However the first line of method with block can be parsed as a valid
        # method or attribute call. In order to avoid that, we had to add this
        # lookahead hack, that treats any expressions as multiline when
        # the following line is indented by more that 4 spaces.
        next_line = lines[index + 1] || ''

        if /\A {5}/.match?(next_line)
          multi_line ||= ''
          multi_line += line
          @multi_no ||= @line_no
          next
        end

        t = parser.parse(line)

        if !t
          err(ParseError, 'syntax error') unless /^\s+/.match?(line)

          multi_line = line
          @multi_no = @line_no
        else
          generate(t)
        end
      end

      if multi_line
        t = parser.parse(multi_line)
        err(ParseError, 'syntax error') unless t
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
      @node_attrs.keys.each_with_object({}) do |node, h|
        h[node] = enumerate_attrs_by_node(node)
      end
    end

    # enumerate qualified list of attrs by node
    def enumerate_attrs_by_node(node)
      raise 'bad node' unless node

      begin
        klass = node.is_a?(String) ? @m.module_eval(node) : node
      rescue NameError
        # FIXME: a little hacky.  Should raise an exception.
        return []
      end

      raise "bad node class #{klass}" unless klass.is_a?(Class)

      klass.methods.map(&:to_s).select do |x|
        x.end_with?(POST)
      end.map do |x|
        x.sub(/#{POST}$/, '')
      end
    end

    # enumerate all params
    def enumerate_params
      @param_set
    end

    # enumerate params by a single node
    def enumerate_params_by_node(node)
      attrs = enumerate_attrs_by_node(node)
      Set.new(attrs.select { |a| @param_set.include?(a) })
    end

    ######################################################################
    # Runtime
    ######################################################################

    def evaluate(node, attrs, params = {})
      raise 'bad params' unless params.is_a?(Hash)

      if node.is_a?(Class)
        klass = node
      else
        raise "bad node '#{node}'" unless /^[A-Z][a-zA-Z0-9_]*$/.match?(node)

        begin
          klass = @m.const_get(node)
        rescue NameError
          err(UndefinedNodeError, "node #{node} is undefined")
        end
      end

      params[:_engine] = self

      if klass.respond_to?(NODE_CACHE_ARG) && klass.send(NODE_CACHE_ARG, params)
        return _evaluate_with_cache(klass, attrs, params)
      end

      if attrs.is_a?(Array)
        attrs.map do |attr|
          unless /^[_a-z][A-Za-z0-9_]*$/.match?(attr)
            raise "bad attribute '#{attr}'"
          end

          klass.send("#{attr}#{POST}".to_sym, params)
        end
      else
        unless /^[_a-z][A-Za-z0-9_]*$/.match?(attrs)
          raise "bad attribute '#{attrs}'"
        end

        klass.send("#{attrs}#{POST}".to_sym, params)
      end
    end

    def _evaluate_with_cache(klass, attrs, params)
      if attrs.is_a?(Array)
        attrs.map do |attr|
          unless /^[_a-z][A-Za-z0-9_]*$/.match?(attr)
            raise "bad attribute '#{attr}'"
          end

          _evaluate_attr_with_cache(klass, attr, params)
        end
      else
        unless /^[_a-z][A-Za-z0-9_]*$/.match?(attrs)
          raise "bad attribute '#{attrs}'"
        end

        _evaluate_attr_with_cache(klass, attrs, params)
      end
    end

    def _evaluate_attr_with_cache(klass, attr, params)
      params_without_engine = params.reject { |k, _| k == :_engine }

      ::Delorean::Cache.with_cache(
        klass: klass,
        method: attr,
        mutable_params: params,
        params: params_without_engine
      ) do
        klass.send("#{attr}#{POST}".to_sym, params)
      end
    end

    def eval_to_hash(node, attrs, params = {})
      res = evaluate(node, attrs, params)
      Hash[* attrs.zip(res).flatten(1)]
    end

    def self.grok_runtime_exception(exc)
      # parse out the delorean-related backtrace records
      bt = exc.backtrace.map do |x|
        x =~ /^#{MOD}(.+?):(\d+)(|:in `(.+)')$/
        $1 && [$1, $2.to_i, $4.sub(/#{POST}$/, '')]
      end.reject(&:!)

      { 'error' => exc.message, 'backtrace' => bt }
    end

    ######################################################################
  end
end
