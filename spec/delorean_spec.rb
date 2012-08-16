require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Delorean" do

  let(:engine) {Delorean::Engine.new}

  it "can parse simple expressions" do
    a_node = "A:\n  "
    engine.parse a_node + "a = 1 + 2 + 3"
  end

end
