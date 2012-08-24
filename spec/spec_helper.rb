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
  t.timestamps
end

class Dummy < ActiveRecord::Base
  def self.i_just_met_you(name, number)
    Dummy.new(name: name, number: number)
  end

  I_JUST_MET_YOU_SIG = [2, 2]

  def self.call_me_maybe(*a)
    a.inject(0, :+)
  end

  CALL_ME_MAYBE_SIG = [0, Float::INFINITY]

  def self.hey_this_is_crazy
  end
end

######################################################################
