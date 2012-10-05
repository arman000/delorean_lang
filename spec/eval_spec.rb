require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Delorean" do

  let(:engine) {
    Delorean::Engine.new "XXX"
  }

  it "evaluate simple expressions" do
    engine.parse defn("A:",
                      "  a = 123",
                      "  x = -(a * 2)",
                      "  b = -(a + 1)",
                      "  c = -a + 1",
                      )
    
    engine.evaluate_attrs("A", ["a"]).should == [123]

    r = engine.evaluate_attrs("A", ["x", "b"])
    r.should == [-246, -124]
  end

  it "proper unary expression evaluation" do
    engine.parse defn("A:",
                      "  a = 123",
                      "  c = -a + 1",
                      )

    r = engine.evaluate("A", "c")
    r.should == -122
  end

  it "should be able to evaluate multiple node attrs" do
    engine.parse defn("A:",
                      "  a =? 123",
                      "  b = a % 11",
                      "  c = a / 4.0",
                      )

    r = engine.evaluate_attrs("A", ["c", "b"], {"a" => 16})
    r.should == [4, 5]
  end

  it "should give error when accessing undefined attr" do
    engine.parse defn("A:",
                      "  a = 1",
                      "  c = a.to_s",
                      )

    lambda {
      r = engine.evaluate("A", "c")
    }.should raise_error(Delorean::InvalidGetAttribute)
  end

  it "should handle default param values" do
    engine.parse defn("A:",
                      "  a =? 123",
                      "  c = a / 123.0",
                      )

    r = engine.evaluate("A", "c")
    r.should == 1
  end

  it "should give error when param is undefined for eval" do
    engine.parse defn("A:",
                      "  a = ?",
                      "  c = a / 123.0",
                      )

    lambda {
      r = engine.evaluate("A", "c")
    }.should raise_error(Delorean::UndefinedParamError)
  end

  it "should handle simple param computation" do
    engine.parse defn("A:",
                      "  a = ?",
                      "  c = a / 123.0",
                      )

    r = engine.evaluate("A", "c", {"a" => 123})
    r.should == 1
  end

  it "should give error on unknown node" do
    engine.parse defn("A:",
                      "  a = 1",
                      )

    lambda {
      r = engine.evaluate("B", "a")
    }.should raise_error(Delorean::UndefinedNodeError)
  end

  it "should handle runtime errors and report module/line number" do
    engine.parse defn("A:",
                      "  a = 1/0",
                      "  b = 10 * a",
                      )
    
    begin
      engine.evaluate("A", "b")
    rescue => exc
      res = engine.parse_runtime_exception(exc)
    end

    res.should == ["divided by 0", [["XXX", 2, "/"], ["XXX", 2, "a"], ["XXX", 3, "b"]]]
  end

  it "should handle runtime errors 2" do
    engine.parse defn("A:",
                      "  b = Dummy.call_me_maybe('a', 'b')",
                      )
    
    begin
      engine.evaluate("A", "b")
    rescue => exc
      res = engine.parse_runtime_exception(exc)
    end

    res[1].should == [["XXX", 2, "b"]]
  end

  it "should cache attr results and reuse them" do
    engine.parse defn("A:",
                      "  b = TIMESTAMP()",
                      "  c = TIMESTAMP()",
                      "B: A",
                      "C:",
                      "  b = TIMESTAMP()",
                      )

    _e = {}

    rb = engine.evaluate("A", "b", _e)
    sleep(0.1)
    rc = engine.evaluate("A", "c", _e)

    rb.should_not == rc

    rbb = engine.evaluate("A", "b", _e)
    rcc = engine.evaluate("A", "c", _e)

    rb.should == rbb
    rc.should == rcc

    rbbb = engine.evaluate("B", "b", _e)
    rccc = engine.evaluate("B", "c", _e)

    rb.should == rbbb
    rc.should == rccc

    r3 = engine.evaluate("C", "b", _e)
    r3.should_not == rb

    sleep(0.1)

    r3.should == engine.evaluate("C", "b", _e)
  end

  it "should properly report error on missing modules" do
    pending
  end

  it "should handle operator precedence properly" do
    engine.parse defn("A:",
                      "  b = 3+2*4-1",
                      "  c = b*3+5",
                      "  d = b*2-c*2",
                      "  e = if (d < -10) then -123-1 else -456+1",
                      )

    r = engine.evaluate("A", "d")
    r.should == -50

    r = engine.evaluate("A", "e")
    r.should == -124
  end

  it "should handle if/else" do
    text = defn("A:",
                "  d =? -10",
                '  e = if d < -10 then "gungam"+"style" else "korea"'
                )

    engine.parse text
    r = engine.evaluate("A", "e", {"d" => -100})
    r.should == "gungam"+"style"

    r = engine.evaluate("A", "e")
    r.should == "korea"
  end

  it "should be able to access specific node attrs " do
    engine.parse defn("A:",
                      "  b = 123",
                      "  c = ?",
                      "B: A",
                      "  b = 111",
                      "  c = A.b * 123",
                      "C:",
                      "  c = A.c + B.c",
                      )
    
    r = engine.evaluate("B", "c")
    r.should == 123*123
    r = engine.evaluate("C", "c", {"c" => 5})
    r.should == 123*123 + 5
  end

  it "should be able to call class methods on ActiveRecord classes" do
    engine.parse defn("A:",
                      "  b = Dummy.call_me_maybe(1, 2, 3, 4)",
                      "  c = Dummy.call_me_maybe()",
                      "  d = Dummy.call_me_maybe(5) + b + c",
                      )
    r = engine.evaluate_attrs("A", ["b", "c", "d"])
    r.should == [10, 0, 15]
  end

  it "should be able to get attr on ActiveRecord objects using a.b syntax" do
    engine.parse defn("A:",
                      '  b = Dummy.i_just_met_you("this is crazy", 0.404)',
                      "  c = b.number",
                      "  d = b.name",
                      "  e = b.foo",
                      )
    r = engine.evaluate("A", "c")
    r.should == 0.404

    r = engine.evaluate("A", "d")
    r.should == "this is crazy"

    lambda {
      r = engine.evaluate("A", "e")
    }.should raise_error(Delorean::InvalidGetAttribute)
  end

  it "should be able to call class methods on ActiveRecord classes in modules" do
    engine.parse defn("A:",
                      "  b = M::LittleDummy.heres_my_number(867, 5309)",
                      )
    r = engine.evaluate("A", "b")
    r.should == 867 + 5309
  end

  it "should not eval inside strings" do
    engine.parse defn("A:",
                      '  d = "#{this is a test}"',
                      )

    r = engine.evaluate("A", "d")
    r.should == '#{this is a test}'
  end

  it "should ignore undeclared params sent to eval which match attr names" do
    engine.parse defn("A:",
                      "  d = 12",
                      )
    r = engine.evaluate("A", "d", {"d" => 5, "e" => 6})
    r.should == 12
  end

end
