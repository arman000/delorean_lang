require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Delorean" do

  let(:engine) {
    Delorean::Engine.new("YYY")
  }

  it "can enumerate nodes" do
    engine.parse defn("X:",
                      "  a = 123",
                      "  b = a",
                      "Y: X",
                      "A:",
                      "XX: Y",
                      "  a = 11",
                      "  c =?",
                      "  d = 456",
                      )
    engine.enumerate_nodes.should == SortedSet.new(["A", "X", "XX", "Y"])
  end

  it "can enumerate all attrs" do
    engine.parse defn("X:",
                      "  a = 123",
                      "  b = a",
                      "Y: X",
                      "Z:",
                      "XX: Y",
                      "  a = 11",
                      "  c =?",
                      "  d = 456",
                      )
    engine.enumerate_attrs.should == {
      "X"=>["a", "b"],
      "Y"=>["a", "b"],
      "Z"=>[],
      "XX"=>["a", "c", "d", "b"],
    }
  end

  it "can enumerate attrs by node" do
    engine.parse defn("X:",
                      "  a = 123",
                      "  b = a",
                      "Y: X",
                      "Z:",
                      "XX: Y",
                      "  a = 11",
                      "  c =?",
                      "  d = 456",
                      )
    engine.enumerate_attrs_by_node("X").should == ["a", "b"]
    engine.enumerate_attrs_by_node("Y").should == ["a", "b"]
    engine.enumerate_attrs_by_node("Z").should == []
    engine.enumerate_attrs_by_node("XX").should == ["a", "c", "d", "b"]
  end

  it "can enumerate params" do
    engine.parse defn("X:",
                      "  a =? 123",
                      "  b = a",
                      "Y: X",
                      "Z:",
                      "XX: Y",
                      "  a = 11",
                      "  c =?",
                      "  d = 123",
                      "YY: XX",
                      "  c =? 22",
                      "  e =? 11",
                      )

    engine.enumerate_params.should == Set.new(["a", "c", "e"])
  end

  it "can enumerate params by node" do
    engine.parse defn("X:",
                      "  a =? 123",
                      "  b = a",
                      "Y: X",
                      "Z:",
                      "XX: Y",
                      "  a = 11",
                      "  c =?",
                      "  d = 123",
                      "YY: XX",
                      "  c =? 22",
                      "  e =? 11",
                      )
    engine.enumerate_params_by_node("X").should == Set.new(["a"])
    engine.enumerate_params_by_node("XX").should == Set.new(["a", "c"])
    engine.enumerate_params_by_node("YY").should == Set.new(["a", "c", "e"])
    engine.enumerate_params_by_node("Z").should == Set.new([])
  end
end
