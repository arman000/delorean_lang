# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'Delorean' do
  let(:sset) do
    TestContainer.new(
      'AAA' =>
      defn('X:',
           '    a = 123',
           '    b = a',
          )
    )
  end

  let(:engine) do
    Delorean::Engine.new 'YYY', sset
  end

  it 'can parse very simple calls' do
    engine.parse defn('X:',
                      '    a = 123',
                      '    b = a',
                     )
  end

  it 'can parse simple expressions - 1' do
    engine.parse defn('A:',
                      '    a = 123',
                      '    x = -(a*2)',
                      '    b = -(a + 1)',
                     )
  end

  it 'can parse simple expressions - 2' do
    engine.parse defn('A:',
                      '    a = 1 + 2 * -3 - -4',
                     )
  end

  it 'can parse params' do
    engine.parse defn('A:',
                      '    a =?',
                      '    b =? a*2',
                     )
  end

  it 'can parse indexing' do
    engine.parse defn('A:',
                      '    b = [1,2,3][1]',
                     )
  end

  it 'can parse indexing with getattr' do
    engine.parse defn('A:',
                      "    a = {'x': [1,2,3]}",
                      '    b = a.x[1]',
                     )
  end

  it 'should accept default param definitions' do
    expect do
      engine.parse defn('A:',
                        '    a =? 0.0123',
                        '    b =? 0',
                        '    c =? -1.1',
                        '    d = b + c',
                       )
    end.not_to raise_error
  end

  it 'gives errors with attrs not in node' do
    expect do
      engine.parse defn('a = 123',
                        'b = a * 2',
                       )
    end.to raise_error(Delorean::ParseError)
  end

  it 'should disallow .<digits> literals' do
    expect do
      engine.parse defn('A:',
                        '    a = .123',
                       )
    end.to raise_error(Delorean::ParseError)
  end

  it 'should disallow leading 0s in numbers' do
    expect do
      engine.parse defn('A:',
                        '    a = 00.123',
                       )
    end.to raise_error(Delorean::ParseError)
  end

  it 'should disallow leading 0s in numbers (2)' do
    expect do
      engine.parse defn('A:',
                        '    a = 0123',
                       )
    end.to raise_error(Delorean::ParseError)
  end

  it 'should disallow bad attr names' do
    expect do
      engine.parse defn('A:',
                        '    B = 1',
                       )
    end.to raise_error(Delorean::ParseError)

    engine.reset

    expect do
      engine.parse defn('A:',
                        '    _b = 1',
                       )
    end.to raise_error(Delorean::ParseError)
  end

  it 'should disallow bad node names' do
    expect do
      engine.parse defn('a:',
                       )
    end.to raise_error(Delorean::ParseError)

    engine.reset

    expect do
      engine.parse defn('_A:',
                       )
    end.to raise_error(Delorean::ParseError)
  end

  it 'should disallow recursion' do
    expect do
      engine.parse defn('A:',
                        '    a = 1',
                        'B: A',
                        '    a = a + 1',
                       )
    end.to raise_error(Delorean::RecursionError)

    engine.reset

    expect do
      engine.parse defn('A:',
                        '    a = 1',
                        'B: A',
                        '    b = a',
                        '    a = b',
                       )
    end.to raise_error(Delorean::RecursionError)
  end

  it 'should allow getattr in expressions' do
    engine.parse defn('A:',
                      '    a = 1',
                      '    b = A.a * A.a - A.a',
                     )
  end

  it 'should allow in expressions' do
    engine.parse defn('A:',
                      '    int =? 1',
                      '    a = if int>1 then int*2 else int/2',
                      '    b = int in [1,2,3]',
                     )
  end

  it 'should allow non-recursive code 1' do
    # this is not a recursion error
    engine.parse defn('A:',
                      '    a = 1',
                      '    b = 2',
                      'B: A',
                      '    a = A.b',
                      '    b = a',
                     )
  end

  it 'should allow non-recursive code 2' do
    engine.parse defn('A:',
                      '    a = 1',
                      '    b = 2',
                      'B: A',
                      '    a = A.b',
                      '    b = A.b + B.a',
                     )
  end

  it 'should allow non-recursive code 3' do
    engine.parse defn('A:',
                      '    b = 2',
                      '    a = A.b + A.b',
                      '    c = a + b + a + b',
                     )
  end

  it 'should check for recursion with default params 1' do
    expect do
      engine.parse defn('A:',
                        '    a =? a',
                       )
    end.to raise_error(Delorean::UndefinedError)
  end

  it 'should check for recursion with default params 2' do
    expect do
      engine.parse defn('A:',
                        '    a = 1',
                        'B: A',
                        '    b =? a',
                        '    a =? b',
                       )
    end.to raise_error(Delorean::RecursionError)
  end

  it 'gives errors for attrs defined more than once in a node' do
    expect do
      engine.parse defn('B:',
                        '    b = 1 + 1',
                        '    b = 123',
                       )
    end.to raise_error(Delorean::RedefinedError)

    engine.reset

    expect do
      engine.parse defn('B:',
                        '    b =?',
                        '    b = 123',
                       )
    end.to raise_error(Delorean::RedefinedError)

    engine.reset

    expect do
      engine.parse defn('B:',
                        '    b =? 22',
                        '    b = 123',
                       )
    end.to raise_error(Delorean::RedefinedError)
  end

  it 'should raise error for nodes defined more than once' do
    expect do
      engine.parse defn('B:',
                        '    b =?',
                        'B:',
                       )
    end.to raise_error(Delorean::RedefinedError)

    engine.reset

    expect do
      engine.parse defn('B:',
                        'A:',
                        'B:',
                       )
    end.to raise_error(Delorean::RedefinedError)
  end

  it 'should not be valid to derive from undefined nodes' do
    expect do
      engine.parse defn('A: B',
                        '    a = 456 * 123',
                       )
    end.to raise_error(Delorean::UndefinedError)
  end

  it 'should not be valid to use an undefined attr' do
    expect do
      engine.parse defn('A:',
                        '    a = 456 * 123',
                        'B: A',
                        '    b = a',
                        '    c = d',
                       )
    end.to raise_error(Delorean::UndefinedError)
  end

  it 'should not be possible to use a forward definition in hash' do
    expect do
      engine.parse defn('A:',
                        "    c = {'b': 1, 'd' : d}",
                        '    d = 789',
                       )
    end.to raise_error(Delorean::UndefinedError)
  end

  it 'should not be possible to use a forward definition in node call' do
    expect do
      engine.parse defn('A:',
                        '    c = A(b=1, d=d)',
                        '    d = 789',
                       )
    end.to raise_error(Delorean::UndefinedError)
  end

  it 'should not be possible to use a forward definition in array' do
    expect do
      engine.parse defn('A:',
                        '    c = [123, 456, d]',
                        '    d = 789',
                       )
    end.to raise_error(Delorean::UndefinedError)
  end

  it 'should be able to use ruby keywords as identifier' do
    expect do
      engine.parse defn('A:',
                        '    in = 123',
                       )
    end.not_to raise_error

    engine.reset

    expect do
      engine.parse defn('B:',
                        '    in1 = 123',
                       )
    end.not_to raise_error

    engine.reset

    expect do
      engine.parse defn('C:',
                        '    ifx = 123',
                        '    elsey = ifx + 1',
                       )
    end.not_to raise_error

    engine.reset

    expect do
      engine.parse defn('D:',
                        '    true = false',
                       )
    end.not_to raise_error

    engine.reset

    expect do
      engine.parse defn('E:',
                        '    a = 1',
                        '    return=a',
                       )
    end.not_to raise_error

    engine.reset

    skip 'need to fix'

    expect do
      engine.parse defn('D:',
                        '    true_1 = false',
                        '    false_1 = true_1',
                        '    nil_1 = false_1',
                       )
    end.not_to raise_error

    engine.reset
  end

  it 'should parse calls followed by getattr' do
    expect do
      engine.parse defn('A:',
                        '    a = -1',
                        '    b = A().a',
                       )
    end.not_to raise_error
  end

  it 'should be able to chain method calls on model functions' do
    expect do
      engine.parse defn('A:',
                        "    b = Dummy.i_just_met_you('CRJ', 123).name"
                       )
    end.not_to raise_error
  end

  it 'should be able to pass model class to model functions' do
    expect do
      engine.parse defn('A:',
                        '    b = Dummy.i_just_met_you(Dummy, 1)'
                       )
    end.not_to raise_error
  end

  it 'should be able to call class methods on ActiveRecord classes' do
    engine.parse defn('A:',
                      '    b = Dummy.call_me_maybe()',
                     )
  end

  # it 'should get exception on arg count to class method call' do
  # lambda {
  # engine.parse defn('A:',
  # '    b = Dummy.i_just_met_you(1, 2, 3)',
  # )
  # }.should raise_error(Delorean::BadCallError)
  # end
  #
  # it "shouldn't be able to call ActiveRecord methods without signature" do
  # lambda {
  # engine.parse defn('A:',
  # '    b = Dummy.this_is_crazy()',
  # )
  # }.should raise_error(Delorean::UndefinedFunctionError)
  # end

  it 'should be able to call class methods on ActiveRecord classes in modules' do
    engine.parse defn('A:',
                      '    b = M::LittleDummy.heres_my_number(867, 5309)',
                     )
  end

  it 'should be able to override parameters with attribute definitions' do
    engine.parse defn('A:',
                      '    b =? 22',
                      'B: A',
                      '    b = 123',
                      'C: B',
                      '    b =? 11',
                     )
  end

  it 'should be able to access derived attrs' do
    engine.parse defn('A:',
                      '    b =? 22',
                      'B: A',
                      '    c = b * 123',
                      'C: B',
                      '    d =? c * b + 11',
                     )
  end

  it 'should not be able to access attrs not defined in ancestors' do
    expect do
      engine.parse defn('A:',
                        '    b =? 22',
                        'B: A',
                        '    c = b * 123',
                        'C: A',
                        '    d =? c * b + 11',
                       )
    end.to raise_error(Delorean::UndefinedError)
  end

  it 'should be able to access specific node attrs ' do
    engine.parse defn('A:',
                      '    b = 123',
                      '    c = A.b',
                     )

    engine.reset

    engine.parse defn('A:',
                      '    b = 123',
                      'B: A',
                      '    b = 111',
                      '    c = A.b * 123',
                      '    d = B.b',
                     )
  end

  it 'should be able to perform arbitrary getattr' do
    engine.parse defn('A:',
                      '    b = 22',
                      '    c = b.x.y.z',
                     )

    engine.reset

    expect do
      engine.parse defn('B:',
                        '    c = b.x.y.z',
                       )
    end.to raise_error(Delorean::UndefinedError)
  end

  it 'should handle lines with comments' do
    engine.parse defn('A: # kaka',
                      '    b = 22  # testing #',
                      '    c = b',
                     )
  end

  it 'should be able to report error line during parse' do
    begin
      engine.parse defn('A:',
                        '    b = 123',
                        'B: .A',
                       )
    rescue StandardError => exc
    end

    expect(exc.module_name).to eq('YYY')
    expect(exc.line).to eq(3)

    engine.reset

    begin
      engine.parse defn('A:',
                        '    b = 3 % b',
                       )
    rescue StandardError => exc
    end

    expect(exc.module_name).to eq('YYY')
    expect(exc.line).to eq(2)
  end

  it 'correctly report error line during parse' do
    begin
      engine.parse defn('A:',
                        '    b = [yyy',
                        '        ]',
                        'B:',
                       )
    rescue StandardError => exc
    end

    expect(exc.module_name).to eq('YYY')
    expect(exc.line).to eq(2)
  end

  it 'should raise error on malformed string' do
    expect do
      engine.parse defn('A:',
                        '  d = "testing"" ',
                       )
    end.to raise_error(Delorean::ParseError)
  end

  it 'should not allow inherited ruby methods as attrs' do
    expect do
      engine.parse defn('A:',
                        '    a = name',
                       )
    end.to raise_error(Delorean::UndefinedError)

    engine.reset

    expect do
      engine.parse defn('A:',
                        '    a = new',
                       )
    end.to raise_error(Delorean::UndefinedError)
  end

  it 'should be able to parse lists' do
    engine.parse defn('A:',
                      '    b = []',
                      '    c = [1,2,3]',
                      "    d = [b, c, b, c, 1, 2, '123', 1.1]",
                      '    e = [1, 1+1, 1+1+1]',
                     )

    engine.reset

    expect do
      engine.parse defn('A:',
                        '    a = [',
                       )
    end.to raise_error(Delorean::ParseError)

    engine.reset

    expect do
      engine.parse defn('A:',
                        '    a = []-',
                       )
    end.to raise_error(Delorean::ParseError)
  end

  it "should handle trailing ',' with lists" do
    engine.parse defn('A:',
                      '    b = [1,2,3,]',
                     )

    engine.reset

    expect do
      engine.parse defn('A:',
                        '    a = [,]',
                       )
    end.to raise_error(Delorean::ParseError)

    engine.reset

    expect do
      engine.parse defn('A:',
                        '    a = [1,2,,]',
                       )
    end.to raise_error(Delorean::ParseError)
  end

  it 'should be able to parse hashes' do
    engine.parse defn('A:',
                      '    b = {}',
                      "    c = {'a':1, 'b': 2, 'c':-3}",
                      '    d = [{1:11}, {2: 22}]',
                     )

    engine.reset

    expect do
      engine.parse defn('A:',
                        '    a = {',
                       )
    end.to raise_error(Delorean::ParseError)

    engine.reset

    expect do
      engine.parse defn('A:',
                        '    a = {}+',
                       )
    end.to raise_error(Delorean::ParseError)
  end

  it 'should be able to parse conditional hash literals' do
    engine.parse defn('A:',
                      '    a = {}',
                      "    c = {'a':a if a, 'b': 2, 'c':-3 if 123}",
                     )
  end

  it "should handle trailing ',' with hashes" do
    engine.parse defn('A:',
                      '    b = {-1:1,}',
                     )

    engine.reset

    expect do
      engine.parse defn('A:',
                        '    a = {,}',
                       )
    end.to raise_error(Delorean::ParseError)

    engine.reset

    expect do
      engine.parse defn('A:',
                        '    a = {-1:1,,}',
                       )
    end.to raise_error(Delorean::ParseError)
  end

  it 'should be able to parse list operations ' do
    engine.parse defn('A:',
                      '    b = [] + []',
                     )
  end

  it 'should parse list comprehension' do
    engine.parse defn('A:',
                      '    b = [123 for i in 123]',
                     )
  end

  it 'should parse list comprehension (2)' do
    engine.parse defn('A:',
                      '    b = [i+1 for i in [1,2,3]]',
                     )
  end

  it 'should parse nested list comprehension' do
    engine.parse defn('A:',
                      '    b = [[a+c for c in [4,5]] for a in [1,2,3]]',
                     )
  end

  xit 'should parse cross list comprehension' do
    engine.parse defn('A:',
                      '    b = [a+c for c in [4,5] for a in [1,2,3]]',
                     )
  end

  it 'should accept list comprehension variable override' do
    engine.parse defn('A:',
                      '    b = [b+1 for b in [1,2,3]]',
                     )
  end

  it 'should accept list comprehension variable override (2)' do
    engine.parse defn('A:',
                      '    a = 1',
                      '    b = [a+1 for a in [1,2,3]]',
                     )
  end

  it 'errors out on bad list comprehension' do
    expect do
      engine.parse defn('A:',
                        '    b = [i+1 for x in [1,2,3]]',
                       )
    end.to raise_error(Delorean::UndefinedError)
    engine.reset

    expect do
      engine.parse defn('A:',
                        '    a = [123 for b in b]',
                       )
    end.to raise_error(Delorean::UndefinedError)
    engine.reset

    # disallow nested comprehension var reuse
    expect do
      engine.parse defn('A:',
                        '    b = [[a+1 for a in [4,5]] for a in [1,2,3]]',
                       )
    end.to raise_error(Delorean::RedefinedError)
    engine.reset
  end

  it 'should handle nested comprehension variables' do
    engine.parse defn('A:',
                      '    b = [ a+b for a, b in [] ]',
                     )
  end

  it 'should allow nodes as values' do
    engine.parse defn('A:',
                      '    a = 123',
                      'B:',
                      '    a = A',
                     )
  end

  it 'should parse module calls' do
    engine.parse defn('A:',
                      '    a = 123',
                      '    b = 456 + a',
                      "    n = 'A'",
                      '    c = nil(x = 123, y = 456)',
                      '    d = n(x = 123,',
                      '          y = 456,',
                      '         )',
                     )
  end

  it 'should parse module calls by node name' do
    engine.parse defn('A:',
                      '    a = 123',
                      '    d = A()',
                     )
  end

  it 'should allow positional args to node calls' do
    engine.parse defn('A:',
                      '    d = A(1, 2, 3, a=123, b=456)',
                     )
  end

  it 'should allow node calls to attrs' do
    engine.parse defn('A:',
                      '    x=?',
                      '    a = A(x=123)',
                      '    d = a(x=456).x',
                     )
  end

  it 'allow conditional args to node calls' do
    engine.parse defn('A:',
                      '    d = A(a=1, b=4 if true, c=4 if false)',
                     )
  end

  it 'allow double splats in node calls' do
    engine.parse defn('A:',
                      '    a =?',
                      '    d = A(**a, **(a+a), a=123, b=456)',
                     )
  end

  it 'allow double splats in literal hashes' do
    engine.parse defn('A:',
                      '    a =?',
                      "    d = {'a':1, 2:2, **a, **(a+a)}",
                      '    c = {**a, **(a+a)}',
                     )
  end

  it 'should parse instance calls' do
    engine.parse defn('A:',
                      '    a = [1,2,[4]].flatten(1)',
                     )
  end

  it 'should parse multiline attr defs' do
    engine.parse defn('A:',
                      '    a = [1,',
                      '         2,',
                      '         3]',
                      '    b = 456',
                     )
  end

  xit 'should parse multiline empty list' do
    engine.parse defn('A:',
                      '    a = [',
                      '         ]',
                     )
  end

  it 'should give proper errors on parse multiline attr defs' do
    begin
      engine.parse defn('A:',
                        '    a = [1,',
                        '         2,',
                        '         3];',
                        '    b = 456',
                       )
      raise
    rescue Delorean::ParseError => exc
      expect(exc.line).to eq(2)
    end
  end

  it 'should give proper errors when multiline error falls off the end' do
    begin
      engine.parse defn('A:',
                        '    x = 123',
                        '    a = 1 +',
                        '         2 +',
                       )
      raise
    rescue Delorean::ParseError => exc
      expect(exc.line).to eq(3)
    end
  end

  it "should give proper errors when multiline doesn't end properly" do
    begin
      engine.parse defn('A:',
                        '    a = 1',
                        '    b = [a+1',
                        '        for a in [1,2,3]',
                        'B:',
                       )
      raise
    rescue Delorean::ParseError => exc
      expect(exc.line).to eq(3)
    end
  end

  it 'should error on multiline not properly spaced' do
    begin
      engine.parse defn('A:',
                        '    a = [1,',
                        '    2]',
                        '    b = 456',
                       )
      raise
    rescue Delorean::ParseError => exc
      expect(exc.line).to eq(2)
    end
  end

  # this is a parsing limitation which should go away
  it 'should not parse interpolated strings' do
    begin
      engine.parse defn('A:',
                        '    d = "#{this is a test}"',
                       )
      raise
    rescue Delorean::ParseError => exc
      expect(exc.line).to eq(2)
    end
  end

  it 'should parse imports' do
    engine.parse defn('import AAA',
                      'A:',
                      '    b = 456',
                      'B: AAA::X',
                     )
  end

  it 'should parse question mark methods' do
    engine.parse defn('A:',
                      "    a = {'a': 1, 'b': 2, 'c': 3}",
                      '    b = a.any?',
                      '        key =?',
                      '        value =?',
                      '        result = value > 10',
                     )
  end

  it 'should not parse question mark variables' do
    expect do
      engine.parse defn('A:',
                        "    a? = {'a': 1, 'b': 2, 'c': 3}",
                       )
    end.to raise_error(Delorean::ParseError)
  end

  it 'should not parse question mark variables 2' do
    expect do
      engine.parse defn('A:',
                        "    a?bc = {'a': 1, 'b': 2, 'c': 3}",
                       )
    end.to raise_error(Delorean::ParseError)
  end

  describe 'blocks' do
    it 'should not not work with default values' do
      expect do
        engine.parse defn('A:',
                          '    a = [1, 2, 3]',
                          '    b = a.any()',
                          '        item =?',
                          '        other =? ActiveRecord::Base.all',
                          '        result = item > other',
                          '    c = a.any() { |ActiveRecord::Base.all| true }',
                          '        item =? ActiveRecord::Base.all',
                          '        result = true',
                          '    d = a.any() { |item = 1| true }',
                          '        item =? 1',
                          '        result = true',
                         )
      end.to raise_error(Delorean::ParseError)
    end

    it 'should raise parse error if result formula is not present in block' do
      expect do
        engine.parse defn('A:',
                          '    array = [1, 2, 3]',
                          '    b = array.any?',
                          '        item =?',
                          '        wrong = item > 10',
                         )
      end.to raise_error(
        Delorean::ParseError,
        /result formula is required in blocks/
      )
    end

    it 'should parse blocks' do
      expect do
        engine.parse defn('A:',
                          "    a = {'a': 1, 'b': 2, 'c': 3}",
                          '    b = a.any()',
                          '        key =?',
                          '        value =?',
                          '        result = value > 10',
                          '    c = a.any()',
                          '        key =?',
                          '        value =?',
                          '        result = value > 2',
                          '    d = a.select()',
                          '        key =?',
                          '        value =?',
                          "        result = key == 'a' || value == 2",
                          '    e = a.select()',
                          '        key =?',
                          "        result = key == 'c' || key == 'b'",
                         )
      end.to_not raise_error
    end
  end

  xit 'should parse ERR()' do
    # pending ... wrapping with parens -- (ERR()) works
    engine.parse defn('A:',
                      '    b = ERR() && 123',
                     )
  end

  it 'should disallow import loops' do
    skip 'not implemented yet'
    sset.merge(
      'BBB' =>
      defn('import AAA',
           'import CCC',
          ),
      'CCC' =>
      defn('import BBB',
          ),
    )
    sset.get_engine('CCC')
  end
end
