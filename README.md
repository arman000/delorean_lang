# Delorean

Delorean is a simple functional scripting language.  It is used at
[PENNYMAC][] as a scripting language for a financial modeling system.

![](http://i.imgur.com/qiG7Av6.jpg)

## Installation

    $ gem install delorean_lang

Or add it to your `Gemfile`, etc.

## Usage

    require 'delorean_lang'

    engine = Delorean::Engine.new("MyModule")

    my_code =<<eom
    NodeA:
        param =?
        attr1 = param * 3
        attr2 = attr1 + 3
        attr3 = attr1 / attr2
    NodeB: NodeA
        attr3 = attr1 / NodeA.attr3
    eom

    engine.parse my_code

    engine.evaluate("NodeB", %w{attr1 attr2 attr3}, {"param"=>15})

## The Delorean Language

### Motivation

* The primary motivation for creation of Delorean was to provide a
  simple scripting language for use by financial analysts.

* The scripting language needed to be tightly coupled with
  Ruby. i.e. be able to query ActiveRecord models. Ruby itself was
  deemed too complex for our users. Also, sand-boxing Ruby to prevent
  unauthorized data access did not seem practical.

* Many of the financial models created at [PENNYMAC][] are simple
  modifications of earlier models. It was important for the scripting
  language to provide a simple inheritance model such that major
  parts of these models could be shared.

### Concepts & Tutorial

Delorean is a [functional programming][] language. As such, it eschews
mutable data and state.  There's also no concept of I/O in the classic
sense.

A Delorean script is comprised of a set of Nodes which include a
collection of attribute definitions.  The following is a simple node
definition:

    NodeA:
	    attr1 = 123
	    attr2 = attr1*2

In the above example, `NodeA` is a new node definition. This node
includes two attributes: `attr1` and `attr2`. `attr1` is defined to be
the integer literal `123`. `attr2` is a function which is defined as
`attr1` multiplied by 2.

Computation in Delorean happens through evaluation of node attributes.
Therefore, in the above example, `NodeA.attr2` evaluates to `246`.

Delorean attribute definitions have the following form:

	attr = expression

Where `attr` is an attribute name. Attribute names are required to
match the following regular expression: `[a-z][a-zA-Z0-9_]*`. An
attribute can only be specified once in a node.  Also, any attributes
it refers to in its expression must have been previously defined.

Delorean also provides a mechanism to provide "input" to a
computation.  This is performed thorough a special kind of attribute
called a parameter.  The following example shows the usage of a
parameter:

    NodeB:
	    param =? "hello"
	    attr = param + " world"

In this example, `param` is defined as a parameter whose default value
is `"hello"`, which is a string literal.  If we evaluate `NodeB.attr`
without providing `param`, the result will be the string `"hello
world"`.  If the `param` is sent in with the value `"look out"`, then
`NodeB.attr` will evaluate to `"look out world"`.

The parameter default value is optional.  If no default value if
provided for a parameter, then a value must be sent in if that
parameter is involved in a computation.  Otherwise an error will
result.

An important concept in Delorean is that of node inheritance.  This
mechanism allows nodes to derive functionality from previously defined
nodes.  The following example shows the usage of inheritance:

    USInfo:
		age = ?
		teen_max = 19
		teen_min = 13
		is_teenager = age >= teen_min && age <= teen_max

    IndiaInfo: USInfo
		teen_min = 10

In this example, node `USInfo` provides a definition of a
`is_teenager` when provided with an `age` parameter. Node `IndiaInfo`
is derived from `USInfo` and so it shares all of its attribute
definitions.  However, the `teen_min` attribute has been overridden.
This specifies that the computation of `is_teenager` will use the
newly defined `teen_min`.  Therefore, `IndiaInfo.is_teenager` with
input of `age = 10` will evaluate to `true`.  Whereas,
`USInfo.is_teenager` with input of `age = 10` will evaluate to `false`.

### Debugging

You can use `(ERR())` to add a breakpoint:

```   
USInfo:
    age = ?
    teen_max = 19
    teen_min = 13
    is_teenager = (ERR()) && age >= teen_min && age <= teen_max

```

Then you can call attributes by using their mangled name (e.g. attr__D) and passing the context. attr__D(_e). Of course, you can use `ls` to list available methods.

```
  teen_max__D(_e) # 19
  age__D(_e)
```

### TODO

TODO: provide details on the following topics:

* Supported data types
* Data structures (arrays and hashes)
* List comprehension
* Built-in functions
* Defining Delorean-callable class functions
* External modules

## Implementation

This implementation of Delorean "compiles" script code to
Ruby.

### Calling ruby methods from Delorean

There are two ways of calling ruby code from delorean. First one is to whitelist methods:

```ruby

  ::Delorean::Ruby.whitelist.add__method :any? do |method|
    method.called_on Enumerable
  end

  ::Delorean::Ruby.whitelist.add_method :length do |method|
    method.called_on String
    method.called_on Enumerable
  end

  ::Delorean::Ruby.whitelist.add_method :first do |method|
    method.called_on Enumerable, with: [Integer]
  end

  ::Delorean::Ruby.whitelist.add_class_method :last do |method|
    method.called_on ActiveRecord::Base, with: [Integer]
  end

```

By default Delorean has some methods whitelisted, such as `length`, `min`, `max`, etc. Those can be found in `/lib/delorean/ruby/whitelists/default`. If you don't want to use defaults, you can override whitelist with and empty one.

```ruby

  require 'delorean/ruby/whitelists/empty'

  ::Delorean::Ruby.whitelist = ::Delorean::Ruby::Whitelists::Empty.new

```

Another way is to define methods using `delorean_fn` with optional `private` and `cache` flags.
Use `extend Delorean::Functions` or `include Delorean::Model` in your module or class.

```ruby
class Dummy < ActiveRecord::Base
  include Delorean::Model

  delorean_fn(:heres_my_number) do |*a|
    a.inject(0, :+)
  end

  delorean_fn :private_cached_number, cache: true, private: true do |*a|
    a.inject(0, :+)
  end
end

module DummyModule
  extend Delorean::Functions

  delorean_fn(:heres_my_number) do |*a|
    a.inject(0, :+)
  end
end
```

`heres_my_number` method will be accessible from Delorean code.

```ruby
ExampleScript:
    a = Dummy.heres_my_number(867, 5309)'
    b = DummyModule.heres_my_number(867, 5309)'
```

You can use blocks in your Delorean code:

```ruby
ExampleScript:
    a = [1, 2, 3]
    b = c.any?
        item =?
        result = item > 2
    c = a.reduce(0)
        sum =?
        num =?
        result = sum + num
```

Note that `do ... end` syntax is not supported

### Caching

Delorean provides `cache` flag for `delorean_fn` method that will cache result based on arguments.

```ruby
  delorean_fn :returns_cached_openstruct, cache: true do |timestamp|
    User.all
  end

```

If `::Delorean::Cache.adapter.cache_item?(...)` returns `false` then caching will not be performed.

By default cache keeps the last 1000 of the results per class. You can override it:

```ruby

  ::Delorean::Cache.adapter = ::Delorean::Cache::Adapters::RubyCache.new(size_per_class: 10)

```

If you want use other caching method, you can use your own adapter:

```ruby

  ::Delorean::Cache.adapter = ::My::Custom::Cache::Adapter.new

```

Delorean expects it to have methods with following signatures:

```ruby

  cache_item(klass:, cache_key:, item:)

  fetch_item(klass:, cache_key:, default:)
  fetch_item(klass:, cache_key:, default:)

  cache_key(klass:, method_name:, args:)
  clear!(klass:)
  clear_all!
  cache_item?(klass:, method_name:, args:)

  # See lib/delorean/cache/adapters/base.rb

```

### Node level caching

You can enable caching for a Delorean node with `_cache = true` attribute.

```ruby
ExampleScript:
    param1 =?
    _cache = true
    a = Dummy.heres_my_number(867, 5309)
    b = DummyModule.heres_my_number(867, 5309)
    result = b
```

When node is called, Delorean would check if there is a cached result for a
combination of node parameters values and the attribute that is to be returned.

```ruby
  ExampleScript(param1=1).result # Will calculate result and cache it for calls with `param1=1`
  ExampleScript(param1=1).result # Will fetch the cached result
  ExampleScript(param1=2).result # Will calculate result and cache it for calls with `param1=2`
```


#### Custom Node level caching policy

You can override the callback that Delorean calls before performing the caching.
The callback should return a hash with `:cache` key.
If `cache:` is false, then Delorean wouldn't fetch result from cache or perform caching.

```ruby
::Delorean::Cache.node_cache_callback = lambda do |klass:, method:, params:|
  {
    cache: true,
  }
end

# See lib/delorean/cache.rb

```

TODO: provide details

## Development

### Treetop

Edit treetop rules in `lib/delorean/delorean.treetop`

Use `make treetop-generate` to regenerate `lib/delorean/delorean.rb` based on Treetop logic in `lib/delorean/delorean.treetop`

### Testing

Use `rspec` to run the tests.

## License

Delorean has been released under the MIT license. Please check the
[LICENSE][] file for more details.

[license]: https://github.com/rubygems/rubygems.org/blob/master/MIT-LICENSE
[pennymac]: http://www.pennymacusa.com
[functional programming]: http://en.wikipedia.org/wiki/Functional_programming
