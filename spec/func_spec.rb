require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Delorean" do

  let(:engine) {
    Delorean::Engine.new
  }

  it "should handle MAX as a node name" do
    c = engine.parse defn("MAX:",
                          "  a = MAX(1, 2, 3, 0, -10)",
                          )

    r = engine.evaluate(c, "MAX", "a")
    r.should == 3
  end

  it "should handle MAX" do
    c = engine.parse defn("A:",
                          "  a = MAX(1, 2, 3)",
                          )

    r = engine.evaluate(c, "A", "a")
    r.should == 3
  end

  it "should handle insufficient args" do
    lambda {
      c = engine.parse defn("A:",
                            "  a = MAX(1)",
                            )
    }.should raise_error(Delorean::BadCallError)
  end

  it "should handle MIN" do
    c = engine.parse defn("A:",
                          "  a = MIN(1, 2, -3, 4)",
                          )

    r = engine.evaluate(c, "A", "a")
    r.should == -3
  end

  it "should handle ROUND" do
    c = engine.parse defn("A:",
                          "  a = ROUND(12.3456, 2)",
                          )

    r = engine.evaluate(c, "A", "a")
    r.should == 12.35

    c = engine.parse defn("A:",
                          "  a = ROUND(12.3456, 1)",
                          )

    r = engine.evaluate(c, "A", "a")
    r.should == 12.3

    c = engine.parse defn("A:",
                          "  a = ROUND(12.3456)",
                          )

    r = engine.evaluate(c, "A", "a")
    r.should == 12
  end

end
