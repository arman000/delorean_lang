require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Delorean" do

  let(:engine) {
    Delorean::Engine.new("ZZZ")
  }

  it "should handle MAX as a node name" do
    engine.parse defn("MAX:",
                      "  a = [1, 2, 3, 0, -10].max()",
                      )

    r = engine.evaluate("MAX", "a")
    r.should == 3
  end

  it "should handle MIN" do
    engine.parse defn("A:",
                      "  a = [1, 2, -3, 4].min()",
                      )

    r = engine.evaluate("A", "a")
    r.should == -3
  end

  it "should handle ROUND" do
    engine.parse defn("A:",
                      "  a = 12.3456.round(2)",
                      "  b = 12.3456.round(1)",
                      "  c = 12.3456.round()",
                      )

    r = engine.evaluate_attrs("A", ["a", "b", "c"])
    r.should == [12.35, 12.3, 12]
  end

  it "should handle NUMBER" do
    engine.parse defn("A:",
                      "  a = 12.3456.to_f()",
                      "  b = '12.3456'.to_f()",
                      "  c = '12'.to_f()",
                      )

    r = engine.evaluate_attrs("A", ["a", "b", "c"])
    r.should == [12.3456, 12.3456, 12]
  end

  it "should handle ABS" do
    engine.parse defn("A:",
                      "  a = (-123).abs()",
                      "  b = (-1.1).abs()",
                      "  c = 2.3.abs()",
                      "  d = 0.abs()",
                      )

    r = engine.evaluate_attrs("A", ["a", "b", "c", "d"])
    r.should == [123, 1.1, 2.3, 0]
  end

  it "should handle STRING" do
    engine.parse defn("A:",
                      "  a = 'hello'.to_s()",
                      "  b = 12.3456.to_s()",
                      "  c = [1,2,3].to_s()",
                      )

    r = engine.evaluate_attrs("A", ["a", "b", "c"])
    r.should == ["hello", '12.3456', [1,2,3].to_s]
  end

  it "should handle TIMEPART" do
    engine.parse defn("A:",
                      "  p =?",
                      "  h = p.hour()",
                      "  m = p.min()",
                      "  s = p.sec()",
                      "  d = p.to_date()",
                      )

    p = Time.now
    params = {"p" => p}
    r = engine.evaluate_attrs("A", %w{h m s d}, params)
    r.should == [p.hour, p.min, p.sec, p.to_date]

    # Non time argument should raise an error
    expect { engine.evaluate_attrs("A", ["m"], {"p" => 123}) }.to raise_error

  end

  it "should handle DATEPART" do
    engine.parse defn("A:",
                      "  p =?",
                      "  y = p.year()",
                      "  d = p.day()",
                      "  m = p.month()",
                      )

    p = Date.today
    r = engine.evaluate_attrs("A", ["y", "d", "m"], {"p" => p})
    r.should == [p.year, p.day, p.month]

    # Non date argument should raise an error
    expect { engine.evaluate_attrs("A", ["y", "d", "m"], {"p" => 123}) }.to raise_error
  end

  it "should handle FLATTEN" do
    x = [[1,2,[3]], 4, 5, [6]]

    engine.parse defn("A:",
                      "  a = #{x}",
                      "  b = a.flatten() + a.flatten(1)"
                      )

    engine.evaluate("A", "b").should == x.flatten + x.flatten(1)
  end

  it "should handle ERR" do
    engine.parse defn("A:",
                      "  a = ERR('hello')",
                      "  b = ERR('xx', 1, 2, 3)",
                      )

    expect { engine.evaluate("A", "a") }.to raise_error('hello')

    lambda {
      r = engine.evaluate("A", "b")
    }.should raise_error("xx, 1, 2, 3")
  end

  it "should handle RUBY" do
    x = [[1, 2, [-3]], 4, 5, [6], -3, 4, 5, 0]

    engine.parse defn("A:",
                      "  a = #{x}",
                      "  b = a.flatten()",
                      "  c = a.flatten(1)",
                      "  d = b+c",
                      "  dd = d.flatten()",
                      "  e = dd.sort()",
                      "  f = e.uniq()",
                      "  g = e.length()",
                      "  gg = a.length()",
                      "  l = a.member(5)",
                      "  m = [a.member(5), a.member(55)]",
                      )

    engine.evaluate("A", "c").should == x.flatten(1)
    d = engine.evaluate("A", "d").should == x.flatten + x.flatten(1)
    dd = engine.evaluate("A", "dd")
    engine.evaluate("A", "e").should == dd.sort
    engine.evaluate("A", "f").should == dd.sort.uniq
    engine.evaluate("A", "g").should == dd.length
    engine.evaluate("A", "gg").should == x.length
    engine.evaluate("A", "m").should == [x.member?(5), x.member?(55)]
  end

  it "should handle RUBY slice function" do
    x = [[1, 2, [-3]], 4, [5, 6], -3, 4, 5, 0]

    engine.parse defn("A:",
                      "  a = #{x}",
                      "  b = a.slice(0, 4)",
                      )
    engine.evaluate("A", "b").should == x.slice(0,4)
  end
end
