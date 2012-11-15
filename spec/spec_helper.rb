$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rspec'
require 'delorean'
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
  t.timestamps
end

class Dummy < ActiveRecord::Base
  attr_accessible :name, :number, :dummy
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

  def self.i_threw_a_hash_in_the_well
    {a: 123, "a" => 456, b: 789}
  end

  I_THREW_A_HASH_IN_THE_WELL_SIG = [0, 0]
end

module M
  class LittleDummy < ActiveRecord::Base
    def self.heres_my_number(*a)
      a.inject(0, :+)
    end

    HERES_MY_NUMBER_SIG = [0, Float::INFINITY]
  end
end

######################################################################
