require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Delorean" do

  let(:engine) {
    Delorean::Engine.new("ZZZ")
  }

  it "should handle MAX as a node name" do
    engine.parse defn("MAX:",
                      "  a = MAX(1, 2, 3, 0, -10)",
                      )

    r = engine.evaluate("MAX", "a")
    r.should == 3
  end

  it "should handle MAX" do
    engine.parse defn("A:",
                      "  a = MAX(1, 2, 3)",
                      )

    r = engine.evaluate("A", "a")
    r.should == 3
  end

  it "should handle insufficient args" do
    lambda {
      engine.parse defn("A:",
                        "  a = MAX(1)",
                        )
    }.should raise_error(Delorean::BadCallError)
  end

  it "should handle MIN" do
    engine.parse defn("A:",
                      "  a = MIN(1, 2, -3, 4)",
                      )

    r = engine.evaluate("A", "a")
    r.should == -3
  end

  it "should handle ROUND" do
    engine.parse defn("A:",
                      "  a = ROUND(12.3456, 2)",
                      "  b = ROUND(12.3456, 1)",
                      "  c = ROUND(12.3456)",
                      )

    r = engine.evaluate_attrs("A", ["a", "b", "c"])
    r.should == [12.35, 12.3, 12]
  end

  it "should handle DATEPART" do
    engine.parse defn("A:",
                      "  p =?",
                      "  y = DATEPART(p, 'y')",
                      "  d = DATEPART(p, 'd')",
                      "  m = DATEPART(p, 'm')",
                      )

    p = Date.today
    r = engine.evaluate_attrs("A", ["y", "d", "m"], {"p" => p})
    r.should == [p.year, p.day, p.month]

    # Non date argument should raise an error
    expect { engine.evaluate_attrs("A", ["y", "d", "m"], {"p" => 123}) }.to raise_error
     # Invalid part argument should raise an error
    engine.reset
    engine.parse defn("A:",
                      "  p =?",
                      "  x = DATEPART(p, 'x')",
                      )
    expect { engine.evaluate_attrs("A", ["x"], {"p" => p}) }.to raise_error
  end

  it "should handle DATEADD" do
    engine.parse defn("A:",
                      "  p =?",
                      "  y = DATEADD(p, 1, 'y')",
                      "  d = DATEADD(p, 30, 'd')",
                      "  m = DATEADD(p, 2, 'm')",
                      )

    p = Date.today
    r = engine.evaluate_attrs("A", ["y", "d", "m"], {"p" => p})
    r.should == [p + 1.years, p + 30.days, p + 2.months]

    # Non date argument should raise an error
    expect { engine.evaluate_attrs("A", ["y", "d", "m"], {"p" => 123}) }.to raise_error

    # Invalid interval argument should raise an error
    engine.reset
    engine.parse defn("A:",
                      "  p =?",
                      "  m = DATEADD(p, 1.3, 'm')",
                      )
    expect { engine.evaluate_attrs("A", ["m"], {"p" => p}) }.to raise_error
   
    # Invalid part argument should raise an error
    engine.reset
    engine.parse defn("A:",
                      "  p =?",
                      "  x = DATEADD(p, 1, 'x')",
                      )
    expect { engine.evaluate_attrs("A", ["x"], {"p" => p}) }.to raise_error
  end

end
