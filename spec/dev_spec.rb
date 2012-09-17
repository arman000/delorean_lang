require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Delorean" do

  let(:engine) {
    Delorean::Engine.new("YYY")
  }

  it "can enumerate attrs" do
    engine.parse defn("X:",
                      "  a = 123",
                      "  b = a",
                      "Y: X",
                      "Z:",
                      "XX: Y",
                      "  a = 11",
                      "  c = ?",
                      "  d = 456",
                      )
    engine.enumerate_attrs.should == {
      "X"=>["a", "b"],
      "Y"=>["a", "b"],
      "Z"=>[],
      "XX"=>["a", "c", "d", "b"],
    }
  end

  it "can enumerate params" do
    engine.parse defn("X:",
                      "  a =? 123",
                      "  b = a",
                      "Y: X",
                      "Z:",
                      "XX: Y",
                      "  a = 11",
                      "  c = ?",
                      "  d = 123",
                      "YY: XX",
                      "  c =? 22",
                      "  e =? 11",
                      )

    engine.enumerate_params.should == Set.new(["a", "c", "e"])
  end
end
