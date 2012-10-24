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

  it "should handle DATE_PART" do
    engine.parse defn("A:",
                      "  p =?",
                      "  y = DATE_PART(p, 'y')",
                      "  d = DATE_PART(p, 'd')",
                      "  m = DATE_PART(p, 'm')",
                      )

    r = engine.evaluate_attrs("A", ["y", "d", "m"], {"p" => Date.today})
    r.should == [Date.today.year, Date.today.day, Date.today.month]
  end

end
