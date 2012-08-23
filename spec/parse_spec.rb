require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class Dummy1 < ActiveRecord::Base
  def self.call_me_maybe(*a)
    a.inspect
  end

  CALL_ME_MAYBE_SIG = [0, Float::INFINITY]

  def self.hey_this_is_crazy
  end
end

describe "Delorean" do

  let(:engine) {
    Delorean::Engine.new
  }

  it "can parse simple expressions - 1" do
    engine.parse defn("A:",
                      "  a = 123",
                      "  x = -(a*2)",
                      # "  b = -(a + 1)",
                      )
  end

  it "can parse simple expressions - 2" do
    engine.parse defn("A:",
                      "  a = 1 + 2 * -3 - -4",
                      )
  end

  it "can parse params" do
    engine.parse defn("A:",
                      "  a = ?",
                      "  b =? a*2",
                      )
  end

  it "should accept default param definitions" do
    lambda {
      engine.parse defn("A:",
                        "  b =? 1",
                        "  c =? -1.1",
                        "  d = b + c",
                        )
    }.should_not raise_error
  end

  it "gives errors with attrs not in node" do
    lambda {
      engine.parse defn("a = 123",
                        "b = a * 2",
                        )
    }.should raise_error(Delorean::ParseError)
  end

  it "should disallow bad attr names" do
    lambda {
      engine.parse defn("A:",
                        "  B = 1",
                        )
    }.should raise_error(Delorean::ParseError)

    lambda {
      engine.parse defn("A:",
                        "  _b = 1",
                        )
    }.should raise_error(Delorean::ParseError)

  end

  it "should disallow bad node names" do
    lambda {
      engine.parse defn("a:",
                        )
    }.should raise_error(Delorean::ParseError)

    lambda {
      engine.parse defn("_A:",
                        )
    }.should raise_error(Delorean::ParseError)
  end

  it "should disallow recursion" do
    lambda {
      engine.parse defn("A:",
                        "  a = 1",
                        "B: A",
                        "  a = a + 1",
                        )
    }.should raise_error(Delorean::RecursionError)

    lambda {
      engine.parse defn("A:",
                        "  a = 1",
                        "  b = 2",
                        "B: A",
                        "  a = b * b",
                        "  b = a + a",
                        )
    }.should raise_error(Delorean::RecursionError)

    # this is not a recursion error
    engine.parse defn("A:",
                      "  a = 1",
                      "  b = 2",
                      "B: A",
                      "  a = A.b * A.a",
                      "  b = A.b + a",
                      )
  end

  it "should check for inter-module recusion" do
    # does this even happen?
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
                        "  b = ?",
                        "  b = 123",
                        )
    }.should raise_error(Delorean::RedefinedError)

    lambda {
      engine.parse defn("B:",
                        "  b =? 22",
                        "  b = 123",
                        )
    }.should raise_error(Delorean::RedefinedError)
  end

  it "should raise error for nodes defined more than once" do
    lambda {
      engine.parse defn("B:",
                        "  b = ?",
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

  it "should be able to call other modules with named params" do
    # what's the syntax

    # probably need a module "require" mechanism.  Should not allow
    # recursive require.
    pending
  end

  it "should be able to call class methods on ActiveRecord classes" do
    engine.parse defn("A:",
                      "  b = Dummy1.call_me_maybe()",
                      )
  end

  it "shouldn't be able to call ActiveRecord methods without signature" do
    lambda {
      engine.parse defn("A:",
                        "  b = Dummy1.hey_this_is_crazy()",
                        )
    }.should raise_error(Delorean::UndefinedFunctionError)
  end

  it "should be able to override parameters with attribute definitions" do
    engine.parse defn("A:",
                      "  b =? 22",
                      "B: A",
                      "  b = 123",
                      "C: B",
                      "  b =? 11",
                      )
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

  it "should be able to access derived attrs" do
    engine.parse defn("A:",
                      "  b =? 22",
                      "B: A",
                      "  c = b * 123",
                      "C: B",
                      "  d =? c * b + 11",
                      )
  end

  it "should not be able to access attrs not defined in ancestors" do
    lambda {
      engine.parse defn("A:",
                        "  b =? 22",
                        "B: A",
                        "  c = b * 123",
                        "C: A",
                        "  d =? c * b + 11",
                        )
    }.should raise_error(Delorean::UndefinedError)
  end

  it "should be able to access specific node attrs " do
    engine.parse defn("A:",
                      "  b = 123",
                      "B: A",
                      "  b = 111",
                      "  c = A.b * 123",
                      )

    # # FIXME: how do we distinguish between our Delorean nodes/modules
    # # vs ActiveRecord function calls??

    # v = module_name::node_name.fn(args_list)

    # # inter module node/attr call.
    # n = module_name::node_name(keyword_args)
    # v = n.attr1

    # # implement a getattr.  If the operand is a module node, we call
    # # it.  If it's an ActiveRecord object, then we get the attr
    # # subject to permissions.

  end

  it "should be able to perform arbitrary getattr" do
    engine.parse defn("A:",
                      "  b = 22",
                      "  c = b.x.y.z",
                      )

    lambda {
      engine.parse defn("A:",
                        "  c = b.x.y.z",
                        )
    }.should raise_error(Delorean::UndefinedError)

  end

end
