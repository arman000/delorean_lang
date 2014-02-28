require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Delorean" do

  let(:sset) {
    TestContainer.new({
                        "AAA" =>
                        defn("X:",
                             "  a =? 123",
                             "  b = a*2",
                             )
                      })
  }

  let(:engine) {
    Delorean::Engine.new "XXX", sset
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

  it "should handle getattr in expressions" do
    engine.parse defn("A:",
                      "  a = {'x':123, 'y':456, 'z':789}",
                      "  b = A.a.x * A.a.y - A.a.z",
                      )
    engine.evaluate_attrs("A", ["b"]).should == [123*456-789]
  end

  it "should be able to evaluate multiple node attrs" do
    engine.parse defn("A:",
                      "  a =? 123",
                      "  b = a % 11",
                      "  c = a / 4.0",
                      )

    h = {"a" => 16}
    r = engine.evaluate_attrs("A", ["c", "b"], h)
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

  it "order of attr evaluation should not matter" do
    engine.parse defn("A:",
                      "	a =? 1",
                      "B:",
                      "	a =? 2",
                      "	c = A.a",
                      )
    engine.evaluate_attrs("B", %w{c a}).should == [1, 2]
    engine.evaluate_attrs("B", %w{a c}).should == [2, 1]
  end

  it "params should behave properly with inheritance" do
    engine.parse defn("A:",
                      "	a =? 1",
                      "B: A",
                      "	a =? 2",
                      "C: B",
                      " a =? 3",
                      " b = B.a",
                      " c = A.a",
                      )
    engine.evaluate_attrs("C", %w{a b c}).should == [3, 2, 1]
    engine.evaluate_attrs("C", %w{a b c}, {"a" => 4}).should == [4, 4, 4]
    engine.evaluate_attrs("C", %w{c b a}).should == [1, 2, 3]
  end

  it "should give error when param is undefined for eval" do
    engine.parse defn("A:",
                      "  a =?",
                      "  c = a / 123.0",
                      )

    lambda {
      r = engine.evaluate("A", "c")
    }.should raise_error(Delorean::UndefinedParamError)
  end

  it "should handle simple param computation" do
    engine.parse defn("A:",
                      "  a =?",
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
      res = Delorean::Engine.grok_runtime_exception(exc)
    end

    res.should == {
      "error" => "divided by 0",
      "backtrace" => [["XXX", 2, "/"], ["XXX", 2, "a"], ["XXX", 3, "b"]],
    }
  end

  it "should handle runtime errors 2" do
    engine.parse defn("A:",
                      "  b = Dummy.call_me_maybe('a', 'b')",
                      )

    begin
      engine.evaluate("A", "b")
    rescue => exc
      res = Delorean::Engine.grok_runtime_exception(exc)
    end

    res["backtrace"].should == [["XXX", 2, "b"]]
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
    r.should == "gungamstyle"

    r = engine.evaluate("A", "e")
    r.should == "korea"
  end

  it "should be able to access specific node attrs " do
    engine.parse defn("A:",
                      "  b = 123",
                      "  c =?",
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

  it "should be able to get attr on ActiveRecord objects using Class.method().attr syntax" do
    engine.parse defn("A:",
                      '  b = Dummy.i_just_met_you("CRJ", 1.234).name',
                      )
    r = engine.evaluate("A", "b")
    r.should == "CRJ"
  end

  it "should be able to get attr on Hash objects using a.b syntax" do
    engine.parse defn("A:",
                      '  b = Dummy.i_threw_a_hash_in_the_well()',
                      "  c = b.a",
                      "  d = b.b",
                      "  e = b.this_is_crazy",
                      )
    engine.evaluate_attrs("A", %w{c d e}).should == [456, 789, nil]
  end

  it "get attr on nil should return nil" do
    engine.parse defn("A:",
                      '  b = Dummy.i_just_met_you("CRJ", 1.234).dummy',
                      '  c = b.gaga',
                      '  d = b.gaga || 55',
                      )
    r = engine.evaluate_attrs("A", ["b", "c", "d"])
    r.should == [nil, nil, 55]
  end

  it "should be able to get assoc attr on ActiveRecord objects" do
    engine.parse defn("A:",
                      '  b = Dummy.miss_you_so_bad()',
                      '  c = b.dummy',
                      )
    r = engine.evaluate("A", "c")
    r.name.should == "hello"
  end

  it "should be able to get attr on node" do
    engine.parse defn("A:",
                      "  a = 123",
                      "  b = A",
                      "  c = b.a * 2",
                      )
    engine.evaluate_attrs("A", %w{a c}).should == [123, 123*2]
  end

  getattr_code = <<eoc
A:
	x = 1
B:
	x = 2
C:
	x = 3
D:
	xs = [A, B, C]
E:
	xx = [n.x for n in D.xs]
eoc

  it "should be able to get attr on node 2" do
    engine.parse getattr_code
    engine.evaluate("E", "xx").should == [1,2,3]
  end

  it "should be able to call class methods on AR classes in modules" do
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

  it "should handle different param defaults on nodes" do
    engine.parse defn("A:",
                      "  p =? 1",
                      "  c = p * 123",
                      "B: A",
                      "  p =? 2",
                      "C: A",
                      "  p =? 3",
                      )

    r = engine.evaluate("C", "c", {"p" => 5})
    r.should == 5*123

    r = engine.evaluate("B", "c", {"p" => 10})
    r.should == 10*123

    r = engine.evaluate("A", "c")
    r.should == 1*123

    r = engine.evaluate("B", "c")
    r.should == 2*123

    r = engine.evaluate("C", "c")
    r.should == 3*123
  end

  it "should allow overriding of attrs as params" do
    engine.parse defn("A:",
                      "  a = 2",
                      "  b = a*3",
                      "B: A",
                      "  a =?",
                      )

    r = engine.evaluate("A", "b", {"a" => 10})
    r.should == 2*3

    r = engine.evaluate("B", "b", {"a" => 10})
    r.should == 10*3

    lambda {
      r = engine.evaluate("B", "b")
    }.should raise_error(Delorean::UndefinedParamError)

  end

  sample_script = <<eof
A:
	a = 2
	p =?
	c = a * 2
	pc = p + c

C: A
    p =? 3

B: A
	p =? 5
eof

  it "should allow overriding of attrs as params" do
    engine.parse sample_script

    r = engine.evaluate("C", "c")
    r.should == 4

    r = engine.evaluate("B", "pc")
    r.should == 4 + 5

    r = engine.evaluate("C", "pc")
    r.should == 4 + 3

    lambda {
      r = engine.evaluate("A", "pc")
    }.should raise_error(Delorean::UndefinedParamError)
  end

  it "engines of same name should be independent" do
    engin2 = Delorean::Engine.new(engine.module_name)

    engine.parse defn("A:",
                      "  a = 123",
                      "  b = a*3",
                      "B: A",
                      "  c = b*2",
                      )

    engin2.parse defn("A:",
                      "  a = 222.0",
                      "  b = a/5",
                      "B: A",
                      "  c = b*3",
                      "C:",
                      "  d = 111",
                      )

    engine.evaluate_attrs("A", ["a", "b"]).should == [123, 123*3]
    engin2.evaluate_attrs("A", ["a", "b"]).should == [222.0, 222.0/5]

    engine.evaluate_attrs("B", ["a", "b", "c"]).should == [123, 123*3, 123*3*2]
    engin2.evaluate_attrs("B", ["a", "b", "c"]).should ==
      [222.0, 222.0/5, 222.0/5*3]

    engin2.evaluate("C", "d").should == 111
    lambda {
      engine.evaluate("C", "d")
    }.should raise_error(Delorean::UndefinedNodeError)
  end

  it "should handle invalid expression evaluation" do
    # Should handle errors on expression such as -[] or -"xxx" or ("x"
    # + []) better. Currently, it raises NoMethodError.
    pending
  end

  it "should eval lists" do
    engine.parse defn("A:",
                      "  b = []",
                      "  c = [1,2,3]",
                      "  d = [b, c, b, c, 1, 2, '123', 1.1, -1.23]",
                      "  e = [1, 1+1, 1+1+1, 1*2*4]",
                      )

    engine.evaluate_attrs("A", %w{b c d e}).should ==
      [[],
       [1, 2, 3],
       [[], [1, 2, 3], [], [1, 2, 3], 1, 2, "123", 1.1, -1.23],
       [1, 2, 3, 8],
      ]
  end

  it "should eval list expressions" do
    engine.parse defn("A:",
                      "  b = []+[]",
                      "  c = [1,2,3]+b",
                      "  d = c*2",
                      )

    engine.evaluate_attrs("A", %w{b c d}).should ==
      [[],
       [1, 2, 3],
       [1, 2, 3]*2,
      ]
  end

  it "should eval sets and set comprehension" do
    engine.parse defn("A:",
                      "  a = {-}",
                      "  b = {i*5 for i in {1,2,3}}",
                      "  c = {1,2,3} | {4,5}",
                      )
    engine.evaluate_attrs("A", ["a", "b", "c"]).should ==
      [Set[], Set[5,10,15], Set[1,2,3,4,5]]
  end

  it "should eval list comprehension" do
    engine.parse defn("A:",
                      "  b = [i*5 for i in [1,2,3]]",
                      )
    engine.evaluate("A", "b").should == [5, 10, 15]
  end

  it "should eval nested list comprehension" do
    engine.parse defn("A:",
                      "  b = [[a+c for c in [4,5]] for a in [1,2,3]]",
                      )
    engine.evaluate("A", "b").should == [[5, 6], [6, 7], [7, 8]]

  end

  it "should eval list comprehension variable override" do
    engine.parse defn("A:",
                      "  b = [b/2.0 for b in [1,2,3]]",
                      )
    engine.evaluate("A", "b").should == [0.5, 1.0, 1.5]
  end

  it "should eval list comprehension variable override (2)" do
    engine.parse defn("A:",
                      "  a = 1",
                      "  b = [a+1 for a in [1,2,3]]",
                      )
    engine.evaluate("A", "b").should == [2, 3, 4]
  end

  it "should eval conditional list comprehension" do
    engine.parse defn("A:",
                      "  b = [i*5 for i in [1,2,3,4,5] if i%2 == 1]",
                      "  c = [i/10.0 for i in [1,2,3,4,5] if i>4]",
                      )
    engine.evaluate("A", "b").should == [5, 15, 25]
    engine.evaluate("A", "c").should == [0.5]
  end

  it "should eval hashes" do
    engine.parse defn("A:",
                      "  b = {}",
                      "  c = {'a':1, 'b': 2,'c':3}",
                      "  d = {123*2: -123, 'b_b': 1+1}",
                      "  e = {'x': 1, 'y': 1+1, 'z': 1+1+1, 'zz': 1*2*4}",
                      "  f = {'a': nil, 'b': [1, nil, 2]}",
                      "  g = {b:b, [b]:[1,23], []:345}",
                      )

    engine.evaluate_attrs("A", %w{b c d e f g}).should ==
      [{},
       {"a"=>1, "b"=>2, "c"=>3},
       {123*2=>-123, "b_b"=>2},
       {"x"=>1, "y"=>2, "z"=>3, "zz"=>8},
       {"a"=>nil, "b"=>[1, nil, 2]},
       {{}=>{}, [{}]=>[1, 23], []=>345},
      ]
  end

  it "should eval hash comprehension" do
    engine.parse defn("A:",
                      "  b = {i*5 :i for i in [1,2,3]}",
                      )
    engine.evaluate("A", "b").should == {5=>1, 10=>2, 15=>3}
  end

  it "should eval nested hash comprehension" do
    engine.parse defn("A:",
                      "  b = { a:{a+c:a-c for c in [4,5]} for a in [1,2,3]}",
                      )
    engine.evaluate("A", "b").should ==
      {1=>{5=>-3, 6=>-4}, 2=>{6=>-2, 7=>-3}, 3=>{7=>-1, 8=>-2}}
  end

  it "should eval conditional hash comprehension" do
    engine.parse defn("A:",
                      "  b = {i*5:i+5 for i in [1,2,3,4,5] if i%2 == 1}",
                      "  c = {i/10.0:i*10 for i in [1,2,3,4,5] if i>4}",
                      )
    engine.evaluate("A", "b").should == {5=>6, 15=>8, 25=>10}
    engine.evaluate("A", "c").should == {0.5=>50}
  end

  it "should eval node calls as intermediate results" do
    engine.parse defn("A:",
                      "  a =?",
                      "  e = A(a: 13)",
                      "  d = e.a * 2",
                      "  f = e.d / e.a",
                      )

    engine.evaluate_attrs("A", ["d", "f"]).should == [26, 2]
  end

  it "should eval module calls 1" do
    engine.parse defn("A:",
                      "  a = 123",
                      "  n = A",
                      "  d = n().a",
                      )

    engine.evaluate_attrs("A", %w{d}).should == [123]
  end

  it "should eval module calls 2" do
    engine.parse defn("A:",
                      "  a = 123",
                      "  b = 456 + a",
                      "  n = 'A'",
                      "  c = nil(x: 123, y: 456) % ['a', 'b']",
                      "  d = n(x: 123, y: 456) % ['a', 'b']",
                      "  e = nil() % ['b']",
                      )

    engine.evaluate_attrs("A", %w{n c d e}).should ==
      ["A", {"a"=>123, "b"=>579}, {"a"=>123, "b"=>579}, {"b"=>579}]
  end

  it "should eval module calls 3" do
    engine.parse defn("A:",
                      "  a = 123",
                      "B:",
                      "  n = 'A'",
                      "  d = n().a",
                      )

    engine.evaluate_attrs("B", %w{d}).should == [123]
  end

  it "should be possible to implement recursive calls" do
    engine.parse defn("A:",
                      "  n =?",
                      "  fact = if n <= 1 then 1 else n * A(n: n-1).fact",
                      )

    engine.evaluate("A", "fact", "n" => 10).should == 3628800
  end

  it "should eval module calls by node name" do
    engine.parse defn("A:",
                      "  a = 123",
                      "  b = A().a",
                      )
    engine.evaluate("A", "b").should == 123
  end

  it "should eval multiline expressions" do
    engine.parse defn("A:",
                      "  a = 1",
                      "  b = [a+1",
                      "       for a in [1,2,3]",
                      "	     ]",
                      )
    engine.evaluate("A", "b").should == [2, 3, 4]
  end

  it "should eval multiline expressions" do
    engine.parse defn("A:",
                      "  a = 123",
                      "  b = 456 + ",
                      "      a",
                      "  n = 'A'",
                      "  c = nil(x: 123,",
                      "        y: 456) % ['a', 'b']",
                      "  d = n(",
                      "         x: 123, y: 456) % ['a', 'b']",
                      "  e = nil(",
                      "       ) % ['b']",
                      )

    engine.evaluate_attrs("A", %w{n c d e}).should ==
      ["A", {"a"=>123, "b"=>579}, {"a"=>123, "b"=>579}, {"b"=>579}]
  end

  it "should eval imports" do
    engine.parse defn("import AAA",
                      "A:",
                      "  b = 456",
                      "B: AAA::X",
                      "  a = 111",
                      "  c = AAA::X(a: 456).b",
                      )
    engine.evaluate_attrs("B", ["a", "b", "c"], {}).should ==
      [111, 222, 456*2]
  end

  it "should eval imports (2)" do
    sset.merge({
                 "BBB"  =>
                 defn("import AAA",
                      "B: AAA::X",
                      "  a = 111",
                      "  c = AAA::X(a: -1).b",
                      "  d = a * 2",
                      ),
                 "CCC" =>
                 defn("import BBB",
                      "import AAA",
                      "B: BBB::B",
                      "  e = d * 3",
                      "C: AAA::X",
                      "  d = b * 3",
                      ),
               })

    e2 = sset.get_engine("BBB")

    e2.evaluate_attrs("B", ["a", "b", "c", "d"]).should ==
      [111, 222, -2, 222]

    engine.parse defn("import BBB",
                      "B: BBB::B",
                      "  e = d + 3",
                      )

    engine.evaluate_attrs("B", ["a", "b", "c", "d", "e"]).should ==
      [111, 222, -2, 222, 225]

    e4 = sset.get_engine("CCC")

    e4.evaluate_attrs("B", ["a", "b", "c", "d", "e"]).should ==
      [111, 222, -2, 222, 666]

    e4.evaluate_attrs("C", ["a", "b", "d"]).should == [123, 123*2, 123*3*2]
  end

  it "should eval imports (3)" do
    sset.merge({
                 "BBB" => getattr_code,
                 "CCC" =>
                 defn("import BBB",
                      "X:",
                      "  xx = [n.x for n in BBB::D().xs]",
                      "  yy = [n.x for n in BBB::D.xs]",
                      ),
               })

    e4 = sset.get_engine("CCC")
    e4.evaluate("X", "xx").should == [1,2,3]
    e4.evaluate("X", "yy").should == [1,2,3]
  end

  it "can eval indexing" do
    engine.parse defn("A:",
                      "  a = [1,2,3]",
                      "  b = a[1]",
                      "  c = a[-1]",
                      "  d = {'a' : 123, 'b': 456}",
                      "  e = d['b']",
                      "  f = a[1,2]",
                      )
    r = engine.evaluate_attrs("A", ["b", "c", "e", "f"])
    r.should == [2, 3, 456, [2,3]]
  end

  it "can eval indexing 2" do
    engine.parse defn("A:",
                      "  a = 1",
                      "  b = {'x' : 123, 'y': 456}",
                      "  c = A() % ['a', 'b']",
                      "  d = c['b'].x * c['a'] - c['b'].y",
                      )
    r = engine.evaluate_attrs("A", ["a", "b", "c", "d"])
    r.should ==
      [1, {"x"=>123, "y"=>456}, {"a"=>1, "b"=>{"x"=>123, "y"=>456}}, -333]
  end

  it "should properly eval overridden attrs" do
    engine.parse defn("A:",
                      "  a = 5",
                      "  b = a",
                      "B: A",
                      "  a = 2",
                      "  x = A.b - B.b",
                      "  k = [A.b, B.b]",
                      "  l = [x.b for x in [A, B]]",
                      "  m = [x().b for x in [A, B]]",
                      )

    engine.evaluate("A", "b").should == 5
    engine.evaluate("B", "b").should == 2
    engine.evaluate("B", "x").should == 3
    engine.evaluate("B", "k").should == [5, 2]
    engine.evaluate("B", "l").should == [5, 2]
    engine.evaluate("B", "m").should == [5, 2]
  end

end
