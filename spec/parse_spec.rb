require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Delorean" do

  let(:engine) {
    Delorean::Engine.new("YYY")
  }

  it "can parse very simple calls" do
    engine.parse defn("X:",
                      "  a = 123",
                      "  b = a",
                      )
  end

  it "can parse simple expressions - 1" do
    engine.parse defn("A:",
                      "  a = 123",
                      "  x = -(a*2)",
                      "  b = -(a + 1)",
                      )
  end

  it "can parse simple expressions - 2" do
    engine.parse defn("A:",
                      "  a = 1 + 2 * -3 - -4",
                      )
  end

  it "can parse params" do
    engine.parse defn("A:",
                      "  a =?",
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

  it "should disallow .<digits> literals" do
    lambda {
      engine.parse defn("A:",
                        "  a = .123",
                        )
    }.should raise_error(Delorean::ParseError)
  end

  it "should disallow bad attr names" do
    lambda {
      engine.parse defn("A:",
                        "  B = 1",
                        )
    }.should raise_error(Delorean::ParseError)

    engine.reset

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

    engine.reset

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

    engine.reset

    lambda {
      engine.parse defn("A:",
                        "  a = 1",
                        "B: A",
                        "  b = a",
                        "  a = b",
                        )
    }.should raise_error(Delorean::RecursionError)

  end

  it "should allow non-recursive code 1" do
    # this is not a recursion error
    engine.parse defn("A:",
                      "  a = 1",
                      "  b = 2",
                      "B: A",
                      "  a = A.b",
                      "  b = a",
                      )

  end

  it "should allow non-recursive code 2" do
    engine.parse defn("A:",
                      "  a = 1",
                      "  b = 2",
                      "B: A",
                      "  a = A.b",
                      "  b = A.b + B.a",
                      )
  end

  it "should allow non-recursive code 3" do
    engine.parse defn("A:",
                      "  b = 2",
                      "  a = A.b + A.b",
                      "  c = a + b + a + b",
                      )
  end

  it "should check for recursion with default params 1" do
    lambda {
      engine.parse defn("A:",
                        "  a =? a",
                        )
    }.should raise_error(Delorean::UndefinedError)
  end

  it "should check for recursion with default params 2" do
    lambda {
      engine.parse defn("A:",
                        "  a = 1",
                        "B: A",
                        "  b =? a",
                        "  a =? b",
                        )
    }.should raise_error(Delorean::RecursionError)
  end

  it "gives errors for attrs defined more than once in a node" do
    lambda {
      engine.parse defn("B:",
                        "  b = 1 + 1",
                        "  b = 123",
                        )
    }.should raise_error(Delorean::RedefinedError)

    engine.reset

    lambda {
      engine.parse defn("B:",
                        "  b =?",
                        "  b = 123",
                        )
    }.should raise_error(Delorean::RedefinedError)

    engine.reset

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
                        "  b =?",
                        "B:",
                        )
    }.should raise_error(Delorean::RedefinedError)

    engine.reset

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

  it "should be able to use ruby keywords as identifier" do
    lambda {
      engine.parse defn("A:",
                        "  in = 123",
                        )
    }.should_not raise_error

    engine.reset

    lambda {
      engine.parse defn("B:",
                        "  in1 = 123",
                        )
    }.should_not raise_error

    engine.reset

    lambda {
      engine.parse defn("C:",
                        "  ifx = 123",
                        "  elsey = ifx + 1",
                        )
    }.should_not raise_error

    engine.reset

    lambda {
      engine.parse defn("D:",
                        "  true = false",
                        )
    }.should_not raise_error

    engine.reset

    lambda {
      engine.parse defn("E:",
                        "  a = 1",
                        "  return=a",
                        )
    }.should_not raise_error
  end

  it "should be able to chain method calls on model functions" do
    lambda {
      engine.parse defn("A:",
                        "  b = Dummy.i_just_met_you('CRJ', 123).name"
                        )
    }.should_not raise_error
  end

  it "should be able to call class methods on ActiveRecord classes" do
    engine.parse defn("A:",
                      "  b = Dummy.call_me_maybe()",
                      )
  end

  it "shouldn't be able to call ActiveRecord methods without signature" do
    lambda {
      engine.parse defn("A:",
                        "  b = Dummy.this_is_crazy()",
                        )
    }.should raise_error(Delorean::UndefinedFunctionError)
  end

  it "should be able to call class methods on ActiveRecord classes in modules" do
    engine.parse defn("A:",
                      "  b = M::LittleDummy.heres_my_number(867, 5309)",
                      )
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

  it "should raise error on node attr access without all needed params" do
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
                      "  c = A.b",
                      )

    engine.reset

    engine.parse defn("A:",
                      "  b = 123",
                      "B: A",
                      "  b = 111",
                      "  c = A.b * 123",
                      "  d = B.b",
                      )
  end

  it "should be able to perform arbitrary getattr" do
    engine.parse defn("A:",
                      "  b = 22",
                      "  c = b.x.y.z",
                      )

    engine.reset

    lambda {
      engine.parse defn("B:",
                        "  c = b.x.y.z",
                        )
    }.should raise_error(Delorean::UndefinedError)

  end

  it "should handle lines with comments" do
    engine.parse defn("A: # kaka",
                      "  b = 22  # testing #",
                      "  c = b",
                      )
  end

  it "should be able to report error line during parse" do
    begin
      engine.parse defn("A:",
                        "  b = 123",
                        "B: .A",
                        )
    rescue => exc
    end

    exc.module_name.should == "YYY"
    exc.line.should == 3

    engine.reset

    begin
      engine.parse defn("A:",
                        "  b = 3 % b",
                        )
    rescue => exc
    end

    exc.module_name.should == "YYY"
    exc.line.should == 2
  end

  it "should raise error on malformed string" do
    lambda {
      engine.parse defn("A:",
                        '  d = "testing"" ',
                        )
    }.should raise_error(Delorean::ParseError)
  end

  it "should not allow inherited ruby methods as attrs" do
    lambda {
      engine.parse defn("A:",
                        "  a = name",
                        )
    }.should raise_error(Delorean::UndefinedError)

    engine.reset

    lambda {
      engine.parse defn("A:",
                        "  a = new",
                        )
    }.should raise_error(Delorean::UndefinedError)
  end

  it "should be able to parse lists " do
    engine.parse defn("A:",
                      "  b = []",
                      "  c = [1,2,3]",
                      "  d = [b, c, b, c, 1, 2, '123', 1.1]",
                      "  e = [1, 1+1, 1+1+1]",
                      )

    engine.reset

    lambda {
      engine.parse defn("A:",
                        "  a = [",
                        )
    }.should raise_error(Delorean::ParseError)

    engine.reset

    lambda {
      engine.parse defn("A:",
                        "  a = []-",
                        )
    }.should raise_error(Delorean::ParseError)

  end

  it "should be able to parse list operations " do
    engine.parse defn("A:",
                      "  b = [] + []",
                      )
  end

  it "should parse list comprehension" do
    engine.parse defn("A:",
                      "  b = [i: [] | 123]",
                      )

  end

  it "should parse list comprehension (2)" do
    engine.parse defn("A:",
                      "  b = [i: [1,2,3] | i+1]",
                      )

  end

  it "should parse nested list comprehension" do
    engine.parse defn("A:",
                      "  b = [a: [1,2,3] | [c: [4,5] | a+c]]",
                      )

  end

  it "should accept list comprehension variable override" do
    engine.parse defn("A:",
                      "  b = [b: [1,2,3] | b+1]",
                      )
  end

  it "should accept list comprehension variable override (2)" do
    engine.parse defn("A:",
                      "  a = 1",
                      "  b = [a: [1,2,3] | a+1]",
                      )
  end

  it "errors out on bad list comprehension" do
    lambda {
      engine.parse defn("A:",
                        "  b = [x: [1,2,3] | i+1]",
                        )
    }.should raise_error(Delorean::UndefinedError)
    engine.reset

    lambda {
      engine.parse defn("A:",
                        "  a = [b: b | 123]",
                        )
    }.should raise_error(Delorean::UndefinedError)
    engine.reset

    # disallow nested comprehension var reuse
    lambda {
      engine.parse defn("A:",
                        "  b = [a: [1,2,3] | [a: [4,5] | a+1]]",
                        )
    }.should raise_error(Delorean::RedefinedError)
    engine.reset
  end

  it "should parse module calls" do
    engine.parse defn("A:",
                      "  a = 123",
                      "  b = 456 + a",
                      "  n = 'A'",
                      "  c = @('a', 'b', x: 123, y: 456)",
                      "  d = @n('a', 'b', x: 123, y: 456)",
                      )
  end

  it "should parse module calls by node name" do
    engine.parse defn("A:",
                      "  a = 123",
                      "  d = @A('a')",
                      )
  end

  it "should parse multiline attr defs" do
    engine.parse defn("A:",
                      "  a = [1,",
                      "       2,",
                      "       3]",
                      "  b = 456",
                      )
  end

  it "should give proper errors on parse multiline attr defs" do
    begin
      engine.parse defn("A:",
                        "  a = [1,",
                        "       2,",
                        "       3];",
                        "  b = 456",
                        )
      raise "fail"
    rescue Delorean::ParseError => exc
      exc.line.should == 2
    end
  end

  it "should give proper errors when multiline error falls off the end" do
    begin
      engine.parse defn("A:",
                        "  x = 123",
                        "  a = 1 +",
                        "       2 +",
                        )
      raise "fail"
    rescue Delorean::ParseError => exc
      exc.line.should == 3
    end
  end

end

