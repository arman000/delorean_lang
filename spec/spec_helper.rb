# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'pry'
require 'rspec'
require 'delorean_lang'
require 'active_record'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
end

def defn(*l)
  l.join("\n") + "\n"
end

######################################################################
# ActiveRecord related

ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'

ActiveRecord::Migration.create_table :dummies do |t|
  t.string :name
  t.decimal :number
  t.references :dummy
  t.timestamps null: true
end

class Dummy < ActiveRecord::Base
  include Delorean::Model

  belongs_to :dummy

  delorean_fn :i_just_met_you do |name, number|
    Dummy.new(name: name, number: number)
  end

  delorean_fn :call_me_maybe do |*a|
    a.inject(0, :+)
  end

  def self.this_is_crazy; end

  def self.miss_you_so_bad
    d = Dummy.create(name: 'hello', number: 123)
    Dummy.new(name: 'jello', number: 456, dummy: d)
  end

  delorean_fn :all_of_me, sig: 0 do
    [{ 'name' => 'hello', 'foo' => 'bar' }]
  end

  delorean_fn :i_threw_a_hash_in_the_well do
    { a: 123, 'a' => 456, b: 789 }
  end

  def name2
    "#{name}-#{number.round(4)}"
  end

  delorean_fn :one_or_two, sig: [1, 2] do |a, b = nil|
    [a, b]
  end

  @@foo = 0
  delorean_fn :side_effect, sig: 0 do
    @@foo += 1
  end

  delorean_fn :returns_openstruct, sig: 0 do
    OpenStruct.new('abc' => 'def')
  end

  delorean_fn :returns_cached_openstruct, cache: true, sig: 2 do |first, last|
    OpenStruct.new(first.to_s => last)
  end
end

class DummyChild < Dummy
  def self.hello
    DummyChild.new(name: 'child', number: 99_999)
  end
end

module M
  class LittleDummy
    include Delorean::Model

    delorean_fn(:heres_my_number, sig: [0, Float::INFINITY]) do |*a|
      a.inject(0, :+)
    end

    def self.sup
      LittleDummy.new
    end
  end

  module N
    class NestedDummy < ::M::LittleDummy
    end
  end
end

Delorean::Ruby.whitelist.add_method :name2 do |method|
  method.called_on Dummy
end

module DummyModule
  extend Delorean::Functions

  delorean_fn(:heres_my_number, sig: [0, Float::INFINITY]) do |*a|
    a.inject(0, :+)
  end
end

module M
  DummyModule = ::DummyModule
end

class DeloreanFunctionsClass
  extend Delorean::Functions

  delorean_fn :test_fn, sig: 0 do
    :test_fn_result
  end

  delorean_fn :test_private_fn, private: true do
  end
end

class DeloreanFunctionsChildClass < DeloreanFunctionsClass
  delorean_fn :test_fn2, sig: 0 do
    :test_fn2_result
  end

  def self.test_fn4; end
end

class DifferentClassSameMethod
  extend Delorean::Functions

  delorean_fn :test_fn2, sig: 0 do
    :test_fn2_result_different
  end

  delorean_fn :test_fn3, sig: 0 do |a, b, c, d = :default, e = nil, *args|
    {
      a: a,
      b: b,
      c: c,
      d: d,
      e: e,
      rest: args
    }
  end
end

class RootClass
  def self.test_method(_int_arg)
    :test_method_with_int_arg
  end
end

Delorean::Ruby.whitelist.add_class_method :test_method do |method|
  method.called_on RootClass, with: [Integer]
end

class RootClassChild < RootClass
  def self.test_method(_str_arg)
    :test_method_with_str_arg
  end
end

Delorean::Ruby.whitelist.add_class_method :test_method do |method|
  method.called_on RootClassChild, with: [String]
end

class RootClassChildsChild < RootClassChild
  class << self
    def test_method(_true_arg)
      :test_method_with_true_arg
    end

    private

    def test_private_method
      :test_private_method
    end
  end
end

Delorean::Ruby.whitelist.add_class_method :test_method do |method|
  method.called_on RootClassChildsChild, with: [TrueClass]
end

Delorean::Ruby.whitelist.add_class_method :test_private_method do |method|
  method.called_on RootClassChildsChild, with: []
end

class RootClassChildsChildsChild < RootClassChildsChild
  def self.test_method2(bool_arg); end
end

Delorean::Ruby.whitelist.add_class_method(
  :match_to_test_fn2,
  match_to: :test_fn2
)

######################################################################

class TestContainer < Delorean::AbstractContainer
  def initialize(scripts = {})
    super()
    @scripts = scripts
    @engines = {}
  end

  def merge(scripts)
    @scripts.merge!(scripts)
  end

  def get_engine(name)
    return @engines[name] if @engines[name]

    script = @scripts[name]

    raise "can't find #{name}" unless script

    engine = Delorean::Engine.new name, self
    engine.parse script
    engine
  end
end

######################################################################
