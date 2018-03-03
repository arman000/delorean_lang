$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rspec'
require 'delorean_lang'
require 'active_record'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|

end

def defn(*l)
  l.join("\n") + "\n"
end

######################################################################
# ActiveRecord related

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

ActiveRecord::Migration.create_table :dummies do |t|
  t.string :name
  t.decimal :number
  t.references :dummy
  t.timestamps null: true
end

class Dummy < ActiveRecord::Base
  include Delorean::Model

  belongs_to :dummy

  def self.i_just_met_you(name, number)
    Dummy.new(name: name, number: number)
  end

  I_JUST_MET_YOU_SIG = [2, 2]

  def self.call_me_maybe(*a)
    a.inject(0, :+)
  end

  CALL_ME_MAYBE_SIG = [0, Float::INFINITY]

  def self.this_is_crazy
  end

  def self.miss_you_so_bad
    d = Dummy.create(name: "hello", number: 123)
    res = Dummy.new(name: "jello", number: 456, dummy: d)
  end

  MISS_YOU_SO_BAD_SIG = [0, 0]

  delorean_fn :all_of_me, sig: 0 do
    [ {"name" => "hello", "foo" => "bar"} ]
  end

  def self.i_threw_a_hash_in_the_well
    {a: 123, "a" => 456, b: 789}
  end

  I_THREW_A_HASH_IN_THE_WELL_SIG = [0, 0]

  def name2
    "#{name}-#{number.round(4)}"
  end

  delorean_fn :one_or_two, sig: [1, 2] do
    |*args|
    # FIXME: |a,b| will not work properly with delorean_fn
    a, b = args

    [a, b]
  end

  def name3 other_name
    "#{name}-#{number.round(4)}-#{other_name}"
  end

  delorean_instance_method :name3, String

  def name4 other_name
    "Four #{name}-#{number.round(4)}-#{other_name}"
  end

  delorean_instance_method :name4, String

  @@foo = 0
  delorean_fn :side_effect, sig: 0 do
    @@foo += 1
  end

  delorean_fn :returns_openstruct, sig: 0 do
    OpenStruct.new({"abc"=>"def"})
  end
end

class DummyChild < Dummy
  def self.hello
    DummyChild.new(name: "child", number: 99999)
  end
  HELLO_SIG = [0, 0]
  def name4 other_name
    "#4 #{name}-#{number.round(4)}-#{other_name}"
  end

  delorean_instance_method :name4, String
end

module M
  class LittleDummy
    include Delorean::Model

    delorean_fn(:heres_my_number, sig: [0, Float::INFINITY]) do
      |*a|
      a.inject(0, :+)
    end
    def self.sup
      LittleDummy.new
    end
    SUP_SIG = [0, 0]
    def foob
      "bar"
    end
    delorean_instance_method :foob
  end

end

Delorean::RUBY_WHITELIST.
  merge!(
         name2: [Dummy],
         )

######################################################################

class TestContainer < Delorean::AbstractContainer
  def initialize(scripts={})
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
