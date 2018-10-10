require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Delorean" do
  let(:sset) {
    TestContainer.new(
                      "AAA" =>
                      defn("X:",
                           "    a = 123",
                           "    b = a",
                           )
                      )
  }

  let(:engine) {
    Delorean::Engine.new "YYY", sset
  }

  it "can parse very simple calls" do
    engine.parse defn("X:",
                      "    a = 123",
                      "    b = a",
                      )
  end

  it "can parse simple expressions - 1" do
    engine.parse defn("A:",
                      "    a = 123",
                      "    x = -(a*2)",
                      "    b = -(a + 1)",
                      )
  end

  it "can parse simple expressions - 2" do
    engine.parse defn("A:",
                      "    a = 1 + 2 * -3 - -4",
                      )
  end

  it "can parse params" do
    engine.parse defn("A:",
                      "    a =?",
                      "    b =? a*2",
                      )
  end

  it "can parse indexing" do
    engine.parse defn("A:",
                      "    b = [1,2,3][1]",
                      )
  end

  it "can parse indexing with getattr" do
    engine.parse defn("A:",
                      "    a = {'x': [1,2,3]}",
                      "    b = a.x[1]",
                      )
  end

  it "should accept default param definitions" do
    lambda {
      engine.parse defn("A:",
                        "    a =? 0.0123",
                        "    b =? 0",
                        "    c =? -1.1",
                        "    d = b + c",
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
                        "    a = .123",
                        )
    }.should raise_error(Delorean::ParseError)
  end

  it "should disallow leading 0s in numbers" do
    lambda {
      engine.parse defn("A:",
                        "    a = 00.123",
                        )
    }.should raise_error(Delorean::ParseError)
  end

  it "should disallow leading 0s in numbers (2)" do
    lambda {
      engine.parse defn("A:",
                        "    a = 0123",
                        )
    }.should raise_error(Delorean::ParseError)
  end

  it "should disallow bad attr names" do
    lambda {
      engine.parse defn("A:",
                        "    B = 1",
                        )
    }.should raise_error(Delorean::ParseError)

    engine.reset

    lambda {
      engine.parse defn("A:",
                        "    _b = 1",
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
                        "    a = 1",
                        "B: A",
                        "    a = a + 1",
                        )
    }.should raise_error(Delorean::RecursionError)

    engine.reset

    lambda {
      engine.parse defn("A:",
                        "    a = 1",
                        "B: A",
                        "    b = a",
                        "    a = b",
                        )
    }.should raise_error(Delorean::RecursionError)

  end

  it "should allow getattr in expressions" do
    engine.parse defn("A:",
                      "    a = 1",
                      "    b = A.a * A.a - A.a",
                      )
  end

  it "should allow in expressions" do
    engine.parse defn("A:",
                      "    int =? 1",
                      "    a = if int>1 then int*2 else int/2",
                      "    b = int in [1,2,3]",
                      )
  end

  it "should allow non-recursive code 1" do
    # this is not a recursion error
    engine.parse defn("A:",
                      "    a = 1",
                      "    b = 2",
                      "B: A",
                      "    a = A.b",
                      "    b = a",
                      )

  end

  it "should allow non-recursive code 2" do
    engine.parse defn("A:",
                      "    a = 1",
                      "    b = 2",
                      "B: A",
                      "    a = A.b",
                      "    b = A.b + B.a",
                      )
  end

  it "should allow non-recursive code 3" do
    engine.parse defn("A:",
                      "    b = 2",
                      "    a = A.b + A.b",
                      "    c = a + b + a + b",
                      )
  end

  it "should check for recursion with default params 1" do
    lambda {
      engine.parse defn("A:",
                        "    a =? a",
                        )
    }.should raise_error(Delorean::UndefinedError)
  end

  it "should check for recursion with default params 2" do
    lambda {
      engine.parse defn("A:",
                        "    a = 1",
                        "B: A",
                        "    b =? a",
                        "    a =? b",
                        )
    }.should raise_error(Delorean::RecursionError)
  end

  it "gives errors for attrs defined more than once in a node" do
    lambda {
      engine.parse defn("B:",
                        "    b = 1 + 1",
                        "    b = 123",
                        )
    }.should raise_error(Delorean::RedefinedError)

    engine.reset

    lambda {
      engine.parse defn("B:",
                        "    b =?",
                        "    b = 123",
                        )
    }.should raise_error(Delorean::RedefinedError)

    engine.reset

    lambda {
      engine.parse defn("B:",
                        "    b =? 22",
                        "    b = 123",
                        )
    }.should raise_error(Delorean::RedefinedError)
  end

  it "should raise error for nodes defined more than once" do
    lambda {
      engine.parse defn("B:",
                        "    b =?",
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
                        "    a = 456 * 123",
                        )
    }.should raise_error(Delorean::UndefinedError)
  end

  it "should not be valid to use an undefined attr" do
    lambda {
      engine.parse defn("A:",
                        "    a = 456 * 123",
                        "B: A",
                        "    b = a",
                        "    c = d",
                        )
    }.should raise_error(Delorean::UndefinedError)
  end

  it "should not be possible to use a forward definition in hash" do
    lambda {
      engine.parse defn("A:",
                        "    c = {'b': 1, 'd' : d}",
                        "    d = 789",
                        )
    }.should raise_error(Delorean::UndefinedError)
  end

  it "should not be possible to use a forward definition in node call" do
    lambda {
      engine.parse defn("A:",
                        "    c = A(b=1, d=d)",
                        "    d = 789",
                        )
    }.should raise_error(Delorean::UndefinedError)
  end

  it "should not be possible to use a forward definition in array" do
    lambda {
      engine.parse defn("A:",
                        "    c = [123, 456, d]",
                        "    d = 789",
                        )
    }.should raise_error(Delorean::UndefinedError)
  end

  it "should be able to use ruby keywords as identifier" do
    lambda {
      engine.parse defn("A:",
                        "    in = 123",
                        )
    }.should_not raise_error

    engine.reset

    lambda {
      engine.parse defn("B:",
                        "    in1 = 123",
                        )
    }.should_not raise_error

    engine.reset

    lambda {
      engine.parse defn("C:",
                        "    ifx = 123",
                        "    elsey = ifx + 1",
                        )
    }.should_not raise_error

    engine.reset

    lambda {
      engine.parse defn("D:",
                        "    true = false",
                        )
    }.should_not raise_error

    engine.reset

    lambda {
      engine.parse defn("E:",
                        "    a = 1",
                        "    return=a",
                        )
    }.should_not raise_error

    engine.reset

    skip "need to fix"

    lambda {
      engine.parse defn("D:",
                        "    true_1 = false",
                        "    false_1 = true_1",
                        "    nil_1 = false_1",
                        )
    }.should_not raise_error

    engine.reset
  end

  it "should parse calls followed by getattr" do
    lambda {
      engine.parse defn("A:",
                        "    a = -1",
                        "    b = A().a",
                        )
    }.should_not raise_error
  end

  it "should be able to chain method calls on model functions" do
    lambda {
      engine.parse defn("A:",
                        "    b = Dummy.i_just_met_you('CRJ', 123).name"
                        )
    }.should_not raise_error
  end

  it "should be able to call class methods on ActiveRecord classes" do
    engine.parse defn("A:",
                      "    b = Dummy.call_me_maybe()",
                      )
  end

  it "should get exception on arg count to class method call" do
    lambda {
      engine.parse defn("A:",
                        '    b = Dummy.i_just_met_you("CRJ")',
                        )
    }.should raise_error(Delorean::BadCallError)
  end

  it "shouldn't be able to call ActiveRecord methods without signature" do
    lambda {
      engine.parse defn("A:",
                        "    b = Dummy.this_is_crazy()",
                        )
    }.should raise_error(Delorean::UndefinedFunctionError)
  end

  it "should be able to call class methods on ActiveRecord classes in modules" do
    engine.parse defn("A:",
                      "    b = M::LittleDummy.heres_my_number(867, 5309)",
                      )
  end

  it "should be able to override parameters with attribute definitions" do
    engine.parse defn("A:",
                      "    b =? 22",
                      "B: A",
                      "    b = 123",
                      "C: B",
                      "    b =? 11",
                      )
  end

  it "should be able to access derived attrs" do
    engine.parse defn("A:",
                      "    b =? 22",
                      "B: A",
                      "    c = b * 123",
                      "C: B",
                      "    d =? c * b + 11",
                      )
  end

  it "should not be able to access attrs not defined in ancestors" do
    lambda {
      engine.parse defn("A:",
                        "    b =? 22",
                        "B: A",
                        "    c = b * 123",
                        "C: A",
                        "    d =? c * b + 11",
                        )
    }.should raise_error(Delorean::UndefinedError)
  end

  it "should be able to access specific node attrs " do
    engine.parse defn("A:",
                      "    b = 123",
                      "    c = A.b",
                      )

    engine.reset

    engine.parse defn("A:",
                      "    b = 123",
                      "B: A",
                      "    b = 111",
                      "    c = A.b * 123",
                      "    d = B.b",
                      )
  end

  it "should be able to perform arbitrary getattr" do
    engine.parse defn("A:",
                      "    b = 22",
                      "    c = b.x.y.z",
                      )

    engine.reset

    lambda {
      engine.parse defn("B:",
                        "    c = b.x.y.z",
                        )
    }.should raise_error(Delorean::UndefinedError)

  end

  it "should handle lines with comments" do
    engine.parse defn("A: # kaka",
                      "    b = 22  # testing #",
                      "    c = b",
                      )
  end

  it "should be able to report error line during parse" do
    begin
      engine.parse defn("A:",
                        "    b = 123",
                        "B: .A",
                        )
    rescue => exc
    end

    exc.module_name.should == "YYY"
    exc.line.should == 3

    engine.reset

    begin
      engine.parse defn("A:",
                        "    b = 3 % b",
                        )
    rescue => exc
    end

    exc.module_name.should == "YYY"
    exc.line.should == 2
  end

  it "correctly report error line during parse" do
    begin
      engine.parse defn("A:",
                        "    b = [yyy",
                        "        ]",
                        "B:",
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
                        "    a = name",
                        )
    }.should raise_error(Delorean::UndefinedError)

    engine.reset

    lambda {
      engine.parse defn("A:",
                        "    a = new",
                        )
    }.should raise_error(Delorean::UndefinedError)
  end

  it "should be able to parse lists" do
    engine.parse defn("A:",
                      "    b = []",
                      "    c = [1,2,3]",
                      "    d = [b, c, b, c, 1, 2, '123', 1.1]",
                      "    e = [1, 1+1, 1+1+1]",
                      )

    engine.reset

    lambda {
      engine.parse defn("A:",
                        "    a = [",
                        )
    }.should raise_error(Delorean::ParseError)

    engine.reset

    lambda {
      engine.parse defn("A:",
                        "    a = []-",
                        )
    }.should raise_error(Delorean::ParseError)

  end

  it "should handle trailing ',' with lists" do
    engine.parse defn("A:",
                      "    b = [1,2,3,]",
                      )

    engine.reset

    lambda {
      engine.parse defn("A:",
                        "    a = [,]",
                        )
    }.should raise_error(Delorean::ParseError)

    engine.reset

    lambda {
      engine.parse defn("A:",
                        "    a = [1,2,,]",
                        )
    }.should raise_error(Delorean::ParseError)
  end

  it "should be able to parse hashes" do
    engine.parse defn("A:",
                      "    b = {}",
                      "    c = {'a':1, 'b': 2, 'c':-3}",
                      "    d = [{1:11}, {2: 22}]",
                      )

    engine.reset

    lambda {
      engine.parse defn("A:",
                        "    a = {",
                        )
    }.should raise_error(Delorean::ParseError)

    engine.reset

    lambda {
      engine.parse defn("A:",
                        "    a = {}+",
                        )
    }.should raise_error(Delorean::ParseError)
  end

  it "should be able to parse conditional hash literals" do
    engine.parse defn("A:",
                      "    a = {}",
                      "    c = {'a':a if a, 'b': 2, 'c':-3 if 123}",
                      )
  end

  it "should handle trailing ',' with hashes" do
    engine.parse defn("A:",
                      "    b = {-1:1,}",
                      )

    engine.reset

    lambda {
      engine.parse defn("A:",
                        "    a = {,}",
                        )
    }.should raise_error(Delorean::ParseError)

    engine.reset

    lambda {
      engine.parse defn("A:",
                        "    a = {-1:1,,}",
                        )
    }.should raise_error(Delorean::ParseError)
  end

  it "should be able to parse list operations " do
    engine.parse defn("A:",
                      "    b = [] + []",
                      )
  end

  it "should parse list comprehension" do
    engine.parse defn("A:",
                      "    b = [123 for i in 123]",
                      )

  end

  it "should parse list comprehension (2)" do
    engine.parse defn("A:",
                      "    b = [i+1 for i in [1,2,3]]",
                      )

  end

  it "should parse nested list comprehension" do
    engine.parse defn("A:",
                      "    b = [[a+c for c in [4,5]] for a in [1,2,3]]",
                      )

  end

  xit "should parse cross list comprehension" do
    engine.parse defn("A:",
                      "    b = [a+c for c in [4,5] for a in [1,2,3]]",
                      )

  end

  it "should accept list comprehension variable override" do
    engine.parse defn("A:",
                      "    b = [b+1 for b in [1,2,3]]",
                      )
  end

  it "should accept list comprehension variable override (2)" do
    engine.parse defn("A:",
                      "    a = 1",
                      "    b = [a+1 for a in [1,2,3]]",
                      )
  end

  it "errors out on bad list comprehension" do
    lambda {
      engine.parse defn("A:",
                        "    b = [i+1 for x in [1,2,3]]",
                        )
    }.should raise_error(Delorean::UndefinedError)
    engine.reset

    lambda {
      engine.parse defn("A:",
                        "    a = [123 for b in b]",
                        )
    }.should raise_error(Delorean::UndefinedError)
    engine.reset

    # disallow nested comprehension var reuse
    lambda {
      engine.parse defn("A:",
                        "    b = [[a+1 for a in [4,5]] for a in [1,2,3]]",
                        )
    }.should raise_error(Delorean::RedefinedError)
    engine.reset
  end

  it "should handle nested comprehension variables" do
    engine.parse defn("A:",
                      "    b = [ a+b for a, b in [] ]",
                      )
  end

  it "should allow nodes as values" do
    engine.parse defn("A:",
                      "    a = 123",
                      "B:",
                      "    a = A",
                      )
  end

  it "should parse module calls" do
    engine.parse defn("A:",
                      "    a = 123",
                      "    b = 456 + a",
                      "    n = 'A'",
                      "    c = nil(x = 123, y = 456)",
                      "    d = n(x = 123,",
                      "          y = 456,",
                      "         )",
                      )
  end

  it "should parse module calls by node name" do
    engine.parse defn("A:",
                      "    a = 123",
                      "    d = A()",
                      )
  end

  it "should allow positional args to node calls" do
    engine.parse defn("A:",
                      "    d = A(1, 2, 3, a=123, b=456)",
                      )
  end

  it "should parse instance calls" do
    engine.parse defn("A:",
                      "    a = [1,2,[4]].flatten(1)",
                      )
  end

  it "should parse multiline attr defs" do
    engine.parse defn("A:",
                      "    a = [1,",
                      "         2,",
                      "         3]",
                      "    b = 456",
                      )
  end

  xit "should parse multiline empty list" do
    engine.parse defn("A:",
                      "    a = [",
                      "         ]",
                      )
  end

  it "should give proper errors on parse multiline attr defs" do
    begin
      engine.parse defn("A:",
                        "    a = [1,",
                        "         2,",
                        "         3];",
                        "    b = 456",
                        )
      fail
    rescue Delorean::ParseError => exc
      exc.line.should == 2
    end
  end

  it "should give proper errors when multiline error falls off the end" do
    begin
      engine.parse defn("A:",
                        "    x = 123",
                        "    a = 1 +",
                        "         2 +",
                        )
      fail
    rescue Delorean::ParseError => exc
      exc.line.should == 3
    end
  end

  it "should give proper errors when multiline doesn't end properly" do
    begin
      engine.parse defn("A:",
                        "    a = 1",
                        "    b = [a+1",
                        "        for a in [1,2,3]",
                        "B:",
                        )
      fail
    rescue Delorean::ParseError => exc
      exc.line.should == 3
    end
  end

  it "should error on multiline not properly spaced" do
    begin
      engine.parse defn("A:",
                        "    a = [1,",
                        "    2]",
                        "    b = 456",
                        )
      fail
    rescue Delorean::ParseError => exc
      exc.line.should == 2
    end
  end

  # this is a parsing limitation which should go away
  it "should not parse interpolated strings" do
    begin
      engine.parse defn("A:",
                        '    d = "#{this is a test}"',
                        )
      fail
    rescue Delorean::ParseError => exc
      exc.line.should == 2
    end
  end

  it "should parse imports" do
    engine.parse defn("import AAA",
                      "A:",
                      "    b = 456",
                      "B: AAA::X",
                      )
  end

  xit "should parse ERR()" do
    # pending ... wrapping with parens -- (ERR()) works
    engine.parse defn("A:",
                      "    b = ERR() && 123",
                      )
  end

  it "should disallow import loops" do
    skip 'not implemented yet'
    sset.merge(
               "BBB" =>
               defn("import AAA",
                    "import CCC",
                    ),
               "CCC" =>
               defn("import BBB",
                    ),
               )
    sset.get_engine("CCC")
  end
end
