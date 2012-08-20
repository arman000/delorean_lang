require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

def defn(*l)
  l.join("\n") + "\n"
end

class Dummy < ActiveRecord::Base
end

describe "Delorean" do

  let(:engine) {
    Delorean::Engine.new
  }

  it "gives errors for unknown ActiveRecord param types" do
    lambda {
      engine.parse defn("A:",
                        "  Mummy? b",
                        )
    }.should raise_error(Delorean::UndefinedError)
  end

  it "can parse simple expressions - 1" do
    engine.parse defn("A:",
                      "  b = a * -a / a",
                      )
  end

  it "can parse simple expressions - 2" do
    engine.parse defn("A:",
                      "  a = 1 + 2 * -3 - -4",
                      )
  end

  it "can parse params" do
    engine.parse defn("A:",
                      "  integer? a",
                      "  Dummy? b",
                      )
  end

  it "gives errors for unknown param types" do
    lambda {
      engine.parse defn("A:",
                        "  junk? b",
                        )
    }.should raise_error(Delorean::ParseError)
  end

  it "gives errors with attrs not in node" do
    lambda {
      engine.parse defn("a = 123",
                        "b = a * 2",
                        )
    }.should raise_error(Delorean::ParseError)
  end

  it "should disallow recursion" do
    # test for a = a + 1

    # also test for a = b; b = a;

    # inter-module recursion shouldn't happen since we won't allow
    # recursive "require".
    pending
  end

  it "gives errors for attrs defined more than once in a node" do
    lambda {
      engine.parse defn("B:",
                        "  b = 1 + 1",
                        "  b = 123",
                        )
    }.should raise_error(Delorean::RedefinedError)

    lambda {
      engine.parse defn("B:",
                        "  integer? b",
                        "  b = 123",
                        )
    }.should raise_error(Delorean::RedefinedError)
  end

  it "should raise error for nodes defined more than once" do
    lambda {
      engine.parse defn("B:",
                        "  integer? b",
                        "B:",
                        )
    }.should raise_error(Delorean::RedefinedError)

    lambda {
      engine.parse defn("B:",
                        "A:",
                        "B:",
                        )
    }.should raise_error(Delorean::RedefinedError)
  end

  it "should not be valid to derive from undefined nodes" do
    lambda {
      engine.parse defn("A: B",
                        "  a = 456 * 123",
                        )
    }.should raise_error(Delorean::UndefinedError)
  end

  it "should not be valid to use an undefined attr" do
    lambda {
      engine.parse defn("A:",
                        "  a = 456 * 123",
                        "B: A",
                        "  b = a",
                        "  c = d",
                        )
    }.should raise_error(Delorean::UndefinedError)
  end

  it "should be an error to use ruby keywords as identifier" do
    lambda {
      engine.parse defn("A:",
                        "  in = 123",
                        )
    }.should raise_error(Delorean::ParseError)

    lambda {
      engine.parse defn("A:",
                        "  in1 = 123",
                        )
    }.should_not raise_error

    lambda {
      engine.parse defn("A:",
                        "  true = false",
                        )
    }.should raise_error(Delorean::ParseError)

    lambda {
      engine.parse defn("A:",
                        "  a = 1",
                        "  return=a",
                        )
    }.should raise_error(Delorean::ParseError)
  end

  it "should cache attr results and reuse them" do
    # can probably test this using the call to a Dummy class method???
    pending
  end

  it "should handle operator precedence properly" do
    pending
  end

  it "should be able to call other modules with named params" do
    # what's the syntax

    # probably need a module "require" mechanism.  Should not allow
    # recursive require.
    pending
  end

  it "should be able to call class methods on ???special??? ActiveRecord classes" do
    pending
  end

  it "should be able to set default values for parameters" do
    pending
  end

  it "should be able to override parameters with attribute definitions" do
    pending
  end

  it "should reject dup param definitions in same node" do
    lambda {
      engine.parse defn("A:",
                        "  integer? a",
                        "  integer? a",
                        )
    }.should raise_error(Delorean::RedefinedError)
  end

  it "should accept default param definitions" do
    lambda {
      engine.parse defn("A:",
                        "  integer? b = 1",
                        "  decimal? c = -1.1",
                        )
    }.should_not raise_error
  end

  it "should be able to get attr on ActiveRecord objects using a.b syntax" do
    pending
  end

  it "should not be able to execute random methods on ActiveRecord objects" do
    # e.g. not be able to call .delete using foo.delete or
    # foo.delete() syntax.
    pending
  end

  it "should be error to exec node attr without providing all needed params" do
    pending
  end

  it "should be possible to list the set of params needed to exec a node attr" do
    # during the parse process, we need to keep track of params used
    # by each attr.  Need to make this available at runtime using a
    # function.  e.g. for each attr "a" have "a_params" which retuns
    # the set of a's params. This works propely wrt inheritance.
    pending
  end

  

end
