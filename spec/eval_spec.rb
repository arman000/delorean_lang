# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'benchmark/ips'
require 'pry'

describe 'Delorean' do
  let(:sset) do
    TestContainer.new(
      'AAA' =>
      defn('X:',
           '    a =? 123',
           '    b = a*2',
          )
    )
  end

  let(:engine) do
    Delorean::Engine.new 'XXX', sset
  end

  it 'evaluate simple expressions' do
    engine.parse defn('A:',
                      '    a = 123',
                      '    x = -(a * 2)',
                      '    b = -(a + 1)',
                      '    c = -a + 1',
                      '    d = a ** 3 - 10*0.2',
                     )

    expect(engine.evaluate('A', ['a'])).to eq([123])

    r = engine.evaluate('A', ['x', 'b'])
    expect(r).to eq([-246, -124])

    expect(engine.evaluate('A', 'd')).to eq 1_860_865.0
  end

  it 'proper unary expression evaluation' do
    engine.parse defn('A:',
                      '    a = 123',
                      '    c = -a + 1',
                     )

    r = engine.evaluate('A', 'c')
    expect(r).to eq(-122)
  end

  it 'proper string interpolation' do
    engine.parse defn('A:',
                      '    a = "\n123\n"',
                     )

    r = engine.evaluate('A', 'a')
    expect(r).to eq("\n123\n")
  end

  it 'should handle getattr in expressions' do
    engine.parse defn('A:',
                      "    a = {'x':123, 'y':456, 'z':789}",
                      '    b = A.a.x * A.a.y - A.a.z',
                     )
    expect(engine.evaluate('A', ['b'])).to eq([123 * 456 - 789])
  end

  it 'should handle numeric getattr' do
    engine.parse defn('A:',
                      "    a = {1:123, 0:456, 'z':789, 2: {'a':444}}",
                      '    b = A.a.1 * A.a.0 - A.a.z - A.a.2.a',
                     )
    expect(engine.evaluate('A', ['b'])).to eq([123 * 456 - 789 - 444])
  end

  it 'should be able to evaluate multiple node attrs' do
    engine.parse defn('A:',
                      '    a =? 123',
                      '    b = a % 11',
                      '    c = a / 4.0',
                     )

    h = { 'a' => 16 }
    r = engine.evaluate('A', ['c', 'b'], h)
    expect(r).to eq([4, 5])
  end

  it 'should give error when accessing undefined attr' do
    engine.parse defn('A:',
                      '    a = 1',
                      '    c = a.to_ss',
                     )

    expect { engine.evaluate('A', 'c') }.to raise_error(
      Delorean::InvalidGetAttribute
    )
  end

  it 'should be able to call 0-ary functions without ()' do
    engine.parse defn('A:',
                      '    a = 1',
                      '    d = a.to_s',
                     )
    expect(engine.evaluate('A', 'd')).to eq('1')
  end

  it 'should handle default param values' do
    engine.parse defn('A:',
                      '    a =? 123',
                      '    c = a / 123.0',
                     )

    r = engine.evaluate('A', 'c')
    expect(r).to eq(1)
  end

  it 'order of attr evaluation should not matter' do
    engine.parse defn('A:',
                      '    a =? 1',
                      'B:',
                      '    a =? 2',
                      '    c = A.a',
                     )
    expect(engine.evaluate('B', %w[c a])).to eq([1, 2])
    expect(engine.evaluate('B', %w[a c])).to eq([2, 1])
  end

  it 'params should behave properly with inheritance' do
    engine.parse defn('A:',
                      '    a =? 1',
                      'B: A',
                      '    a =? 2',
                      'C: B',
                      '    a =? 3',
                      '    b = B.a',
                      '    c = A.a',
                     )
    expect(engine.evaluate('C', %w[a b c])).to eq([3, 2, 1])
    expect(engine.evaluate('C', %w[a b c], 'a' => 4)).to eq([4, 4, 4])
    expect(engine.evaluate('C', %w[c b a])).to eq([1, 2, 3])
  end

  it 'should give error when param is undefined for eval' do
    engine.parse defn('A:',
                      '    a =?',
                      '    c = a / 123.0',
                     )

    expect { engine.evaluate('A', 'c') }.to raise_error(
      Delorean::UndefinedParamError
    )
  end

  it 'should handle simple param computation' do
    engine.parse defn('A:',
                      '    a =?',
                      '    c = a / 123.0',
                     )

    r = engine.evaluate('A', 'c', 'a' => 123)
    expect(r).to eq(1)
  end

  it 'should give error on unknown node' do
    engine.parse defn('A:',
                      '    a = 1',
                     )

    expect { engine.evaluate('B', 'a') }.to raise_error(
      Delorean::UndefinedNodeError
    )
  end

  it 'should handle runtime errors and report module/line number' do
    engine.parse defn('A:',
                      '    a = 1/0',
                      '    b = 10 * a',
                     )

    begin
      engine.evaluate('A', 'b')
    rescue StandardError => exc
      res = Delorean::Engine.grok_runtime_exception(exc)
    end

    expect(res).to eq(
      'error' => 'divided by 0',
      'backtrace' => [['XXX', 2, '/'], ['XXX', 2, 'a'], ['XXX', 3, 'b']],
    )
  end

  it 'should handle runtime errors 2' do
    engine.parse defn('A:',
                      "    b = Dummy.call_me_maybe('a', 'b')",
                     )

    begin
      engine.evaluate('A', 'b')
    rescue StandardError => exc
      res = Delorean::Engine.grok_runtime_exception(exc)
    end

    expect(res['backtrace']).to eq([['XXX', 2, 'b']])
  end

  it 'should handle optional args to external fns' do
    engine.parse defn('A:',
                      "    b = Dummy.one_or_two(['a', 'b'])",
                      "    c = Dummy.one_or_two([1,2,3], ['a', 'b'])",
                     )

    expect(engine.evaluate('A', 'b')).to eq([['a', 'b'], nil])
    expect(engine.evaluate('A', 'c')).to eq([[1, 2, 3], ['a', 'b']])
  end

  it 'should handle if else' do
    engine.parse defn('A:',
                      '    n =?',
                      '    fact = if n <= 1 then 1',
                      '            else n'
                     )

    expect(engine.evaluate('A', 'fact', 'n' => 0)).to eq(1)
    expect(engine.evaluate('A', 'fact', 'n' => 10)).to eq(10)
  end

  it 'should handle elsif 1' do
    engine.parse defn('A:',
                      '    n =?',
                      '    fact = if n <= 1 then 1',
                      '            elsif n < 7 then 7',
                      '            else n'
                     )

    expect(engine.evaluate('A', 'fact', 'n' => 0)).to eq(1)
    expect(engine.evaluate('A', 'fact', 'n' => 5)).to eq(7)
    expect(engine.evaluate('A', 'fact', 'n' => 10)).to eq(10)
  end

  it 'should handle elsif 2' do
    engine.parse defn('A:',
                      '    n =?',
                      '    m = 2',
                      '    fact = if n <= 1 then 1',
                      '            elsif n < 3 then 3',
                      '            elsif (n < 7 && (m + Dummy.call_me_maybe(n)) > 1) then 7',
                      '            else n'
                     )

    expect(engine.evaluate('A', 'fact', 'n' => 0)).to eq(1)
    expect(engine.evaluate('A', 'fact', 'n' => 2)).to eq(3)
    expect(engine.evaluate('A', 'fact', 'n' => 5)).to eq(7)
    expect(engine.evaluate('A', 'fact', 'n' => 10)).to eq(10)
  end

  it 'should handle operator precedence properly' do
    engine.parse defn('A:',
                      '    b = 3+2*4-1',
                      '    c = b*3+5',
                      '    d = b*2-c*2',
                      '    e = if (d < -10) then -123-1 else -456+1',
                     )

    r = engine.evaluate('A', 'd')
    expect(r).to eq(-50)

    r = engine.evaluate('A', 'e')
    expect(r).to eq(-124)
  end

  it 'should handle if/else' do
    text = defn('A:',
                '    d =? -10',
                '    e = if d < -10 then "gungam"+"style" else "korea"'
               )

    engine.parse text
    r = engine.evaluate('A', 'e', 'd' => -100)
    expect(r).to eq('gungamstyle')

    r = engine.evaluate('A', 'e')
    expect(r).to eq('korea')
  end

  it 'should be able to access specific node attrs ' do
    engine.parse defn('A:',
                      '    b = 123',
                      '    c =?',
                      'B: A',
                      '    b = 111',
                      '    c = A.b * 123',
                      'C:',
                      '    c = A.c + B.c',
                     )

    r = engine.evaluate('B', 'c')
    expect(r).to eq(123 * 123)
    r = engine.evaluate('C', 'c', 'c' => 5)
    expect(r).to eq(123 * 123 + 5)
  end

  it 'should be able to access nodes and node attrs dynamically ' do
    engine.parse defn('A:',
                      '    b = 123',
                      'B:',
                      '    b = A',
                      '    c = b.b * 456',
                     )

    r = engine.evaluate('B', 'c')
    expect(r).to eq(123 * 456)
  end

  it 'should be able to call class methods on ActiveRecord classes' do
    engine.parse defn('A:',
                      '    b = Dummy.call_me_maybe(1, 2, 3, 4)',
                      '    c = Dummy.call_me_maybe()',
                      '    d = Dummy.call_me_maybe(5) + b + c',
                     )
    r = engine.evaluate('A', ['b', 'c', 'd'])
    expect(r).to eq([10, 0, 15])
  end

  it 'should be able to access ActiveRecord whitelisted fns using .x syntax' do
    engine.parse defn('A:',
                      '    b = Dummy.i_just_met_you("CRJ", 1.234).name2',
                     )
    r = engine.evaluate('A', 'b')
    expect(r).to eq('CRJ-1.234')
  end

  it 'should be able to get attr on Hash objects using a.b syntax' do
    engine.parse defn('A:',
                      '    b = Dummy.i_threw_a_hash_in_the_well()',
                      '    c = b.a',
                      '    d = b.b',
                      '    e = b.this_is_crazy',
                     )
    expect(engine.evaluate('A', %w[c d e])).to eq([456, 789, nil])
  end

  it 'get attr on nil should return nil' do
    engine.parse defn('A:',
                      '    b = nil',
                      '    c = b.gaga',
                      '    d = b.gaga || 55',
                     )
    r = engine.evaluate('A', ['b', 'c', 'd'])
    expect(r).to eq([nil, nil, 55])
  end

  it 'should be able to get attr on node' do
    engine.parse defn('A:',
                      '    a = 123',
                      '    b = A',
                      '    c = b.a * 2',
                     )
    expect(engine.evaluate('A', %w[a c])).to eq([123, 123 * 2])
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

  it 'should be able to get attr on node 2' do
    engine.parse getattr_code
    expect(engine.evaluate('E', 'xx')).to eq([1, 2, 3])
  end

  it 'should be able to call class methods on AR classes in modules' do
    engine.parse defn('A:',
                      '    b = M::LittleDummy.heres_my_number(867, 5309)',
                      '    c = M::N::NestedDummy.heres_my_number(867, 5309)',
                     )
    r = engine.evaluate('A', 'b')
    expect(r).to eq(867 + 5309)

    r = engine.evaluate('A', 'c')
    expect(r).to eq(867 + 5309)
  end

  it 'should be able to use AR classes as values and call their methods' do
    engine.parse defn('A:',
                      '    a = M::LittleDummy',
                      '    b = a.heres_my_number(867, 5309)',
                      '    c = M::N::NestedDummy.heres_my_number(867, 5309)',
                     )
    r = engine.evaluate('A', 'b')
    expect(r).to eq(867 + 5309)

    r = engine.evaluate('A', 'c')
    expect(r).to eq(867 + 5309)
  end

  it 'should be able to use ruby modules as values and call their methods' do
    engine.parse defn('A:',
                      '    a = DummyModule',
                      '    b = a.heres_my_number(867, 5309)',
                      '    c = M::DummyModule.heres_my_number(867, 5309)',
                     )
    # binding.pry
    r = engine.evaluate('A', 'b')
    expect(r).to eq(867 + 5309)

    r = engine.evaluate('A', 'c')
    expect(r).to eq(867 + 5309)
  end

  it 'should be able call method defined in a parent or matched to' do
    engine.parse defn(
      'A:',
      '    b = DeloreanFunctionsChildClass.test_fn',
      '    c = DeloreanFunctionsChildClass.test_fn2',
      '    d = DifferentClassSameMethod.test_fn2',
      '    e = DifferentClassSameMethod.match_to_test_fn2',
    )

    r = engine.evaluate('A', 'b')
    expect(r).to eq(:test_fn_result)

    r = engine.evaluate('A', 'c')
    expect(r).to eq(:test_fn2_result)

    r = engine.evaluate('A', 'd')
    expect(r).to eq(:test_fn2_result_different)

    r = engine.evaluate('A', 'e')
    expect(r).to eq(:test_fn2_result_different)
  end

  it 'should raise exception if method is not whitelisted' do
    engine.parse defn(
      'A:',
      '    a = DeloreanFunctionsChildClass.test_fn4',
      '    b = DeloreanFunctionsChildClass.test_fn4()',
      '    c = Dummy.this_is_crazy()',
    )

    expect { engine.evaluate('A', 'a') }.to raise_error(
      Delorean::InvalidGetAttribute,
      "attr lookup failed: 'test_fn4' on <Class> DeloreanFunctionsChildClass - no such method test_fn4"
    )

    expect { engine.evaluate('A', 'b') }.to raise_error(
      RuntimeError, 'no such method test_fn4'
    )

    expect { engine.evaluate('A', 'c') }.to raise_error(
      RuntimeError, 'no such method this_is_crazy'
    )
  end

  it 'should be able to call cached_delorean_fn' do
    engine.parse defn(
      'A:',
      '    b = Dummy.returns_cached_openstruct(1, 2)',
      '    c = Dummy.returns_cached_openstruct(1, 2)',
      '    d = Dummy.returns_cached_openstruct(1, 3)',
    )

    expect(OpenStruct).to receive(:new).twice.and_call_original

    r = engine.evaluate('A', 'b')
    expect(r['1']).to eq(2)

    r = engine.evaluate('A', 'c')
    expect(r['1']).to eq(2)

    r = engine.evaluate('A', 'd')
    expect(r['1']).to eq(3)
  end

  it 'should raise exception if required arguments are missing' do
    engine.parse defn(
      'A:',
      '    a = DifferentClassSameMethod.test_fn3(1, 2, 3, 4, 5,
                                                 6, 7, 8, 9, 10)',
      '    b = DifferentClassSameMethod.test_fn3(1, 2, 3, 4) ',
      '    c = DifferentClassSameMethod.test_fn3(1, 2) ',
      '    d = DifferentClassSameMethod.test_fn3() ',
    )

    r = engine.evaluate('A', 'a')
    expect(r).to eq(a: 1, b: 2, c: 3, d: 4, e: 5, rest: [6, 7, 8, 9, 10])

    r = engine.evaluate('A', 'b')
    expect(r).to eq(a: 1, b: 2, c: 3, d: 4, e: nil, rest: [])

    expect { r = engine.evaluate('A', 'c') }.to raise_error(
      ArgumentError,
      'wrong number of arguments (given 2, expected 3+)'
    )

    expect { r = engine.evaluate('A', 'd') }.to raise_error(
      ArgumentError,
      'wrong number of arguments (given 0, expected 3+)'
    )
  end

  it 'should raise exception if private method is called' do
    engine.parse defn(
      'A:',
      '    a = DeloreanFunctionsClass.test_private_fn',
      '    b = DeloreanFunctionsChildClass.test_private_fn'
    )

    expect do
      engine.evaluate('A', 'a')
    end.to raise_error(
      Delorean::InvalidGetAttribute,
      "attr lookup failed: 'test_private_fn' on <Class> DeloreanFunctionsClass - no such method test_private_fn"
    )

    expect do
      engine.evaluate('A', 'b')
    end.to raise_error(
      "attr lookup failed: 'test_private_fn' on <Class> DeloreanFunctionsChildClass - no such method test_private_fn"
    )

    expect do
      DeloreanFunctionsClass.test_private_fn
    end.to raise_error(
      NoMethodError,
      "private method `test_private_fn' called for DeloreanFunctionsClass:Class"
    )
  end

  it 'should ignore undeclared params sent to eval which match attr names' do
    engine.parse defn('A:',
                      '    d = 12',
                     )
    r = engine.evaluate('A', 'd', 'd' => 5, 'e' => 6)
    expect(r).to eq(12)
  end

  it 'should handle different param defaults on nodes' do
    engine.parse defn('A:',
                      '    p =? 1',
                      '    c = p * 123',
                      'B: A',
                      '    p =? 2',
                      'C: A',
                      '    p =? 3',
                     )

    r = engine.evaluate('C', 'c', 'p' => 5)
    expect(r).to eq(5 * 123)

    r = engine.evaluate('B', 'c', 'p' => 10)
    expect(r).to eq(10 * 123)

    r = engine.evaluate('A', 'c')
    expect(r).to eq(1 * 123)

    r = engine.evaluate('B', 'c')
    expect(r).to eq(2 * 123)

    r = engine.evaluate('C', 'c')
    expect(r).to eq(3 * 123)
  end

  it 'should allow overriding of attrs as params' do
    engine.parse defn('A:',
                      '    a = 2',
                      '    b = a*3',
                      'B: A',
                      '    a =?',
                     )

    r = engine.evaluate('A', 'b', 'a' => 10)
    expect(r).to eq(2 * 3)

    r = engine.evaluate('B', 'b', 'a' => 10)
    expect(r).to eq(10 * 3)

    expect { r = engine.evaluate('B', 'b') }.to raise_error(
      Delorean::UndefinedParamError
    )
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

  it 'should allow overriding of attrs as params' do
    engine.parse sample_script

    r = engine.evaluate('C', 'c')
    expect(r).to eq(4)

    r = engine.evaluate('B', 'pc')
    expect(r).to eq(4 + 5)

    r = engine.evaluate('C', 'pc')
    expect(r).to eq(4 + 3)

    expect { r = engine.evaluate('A', 'pc') }.to raise_error(
      Delorean::UndefinedParamError
    )
  end

  it 'engines of same name should be independent' do
    engin2 = Delorean::Engine.new(engine.module_name)

    engine.parse defn('A:',
                      '    a = 123',
                      '    b = a*3',
                      'B: A',
                      '    c = b*2',
                     )

    engin2.parse defn('A:',
                      '    a = 222.0',
                      '    b = a/5',
                      'B: A',
                      '    c = b*3',
                      'C:',
                      '    d = 111',
                     )

    expect(engine.evaluate('A', ['a', 'b'])).to eq(
      [123, 123 * 3]
    )
    expect(engin2.evaluate('A', ['a', 'b'])).to eq(
      [222.0, 222.0 / 5]
    )

    expect(engine.evaluate('B', ['a', 'b', 'c'])).to eq(
      [123, 123 * 3, 123 * 3 * 2]
    )
    expect(engin2.evaluate('B', ['a', 'b', 'c'])).to eq(
      [222.0, 222.0 / 5, 222.0 / 5 * 3]
    )

    expect(engin2.evaluate('C', 'd')).to eq(111)
    expect { engine.evaluate('C', 'd') }.to raise_error(
      Delorean::UndefinedNodeError
    )
  end

  it 'should handle invalid expression evaluation' do
    # Should handle errors on expression such as -[] or -"xxx" or ("x"
    # + []) better. Currently, it raises NoMethodError.
    skip 'handle errors on expressions such as -[] or -"xxx"'
  end

  it 'should eval lists' do
    engine.parse defn('A:',
                      '    b = []',
                      '    c = [1,2,3]',
                      "    d = [b, c, b, c, 1, 2, '123', 1.1, -1.23]",
                      '    e = [1, 1+1, 1+1+1, 1*2*4]',
                     )

    expect(engine.evaluate('A', %w[b c d e])).to eq(
      [[],
       [1, 2, 3],
       [[], [1, 2, 3], [], [1, 2, 3], 1, 2, '123', 1.1, -1.23],
       [1, 2, 3, 8],
      ])
  end

  it 'should eval list expressions' do
    engine.parse defn('A:',
                      '    b = []+[]',
                      '    c = [1,2,3]+b',
                      '    d = c*2',
                     )

    expect(engine.evaluate('A', %w[b c d])).to eq(
      [[],
       [1, 2, 3],
       [1, 2, 3] * 2,
      ])
  end

  it 'should eval sets and set comprehension' do
    engine.parse defn('A:',
                      '    a = {-}',
                      '    b = {i*5 for i in {1,2,3}}',
                      '    c = {1,2,3} | {4,5}',
                     )
    expect(engine.evaluate('A', ['a', 'b', 'c'])).to eq(
      [Set[], Set[5, 10, 15], Set[1, 2, 3, 4, 5]]
    )
  end

  it 'should eval list comprehension' do
    engine.parse defn('A:',
                      '    b = [i*5 for i in [1,2,3]]',
                      '    c = [a-b for a, b in [[1,2],[4,3]]]'
                     )
    expect(engine.evaluate('A', 'b')).to eq([5, 10, 15])
    expect(engine.evaluate('A', 'c')).to eq([-1, 1])
  end

  it 'should eval nested list comprehension' do
    engine.parse defn('A:',
                      '    b = [[a+c for c in [4,5]] for a in [1,2,3]]',
                     )
    expect(engine.evaluate('A', 'b')).to eq([[5, 6], [6, 7], [7, 8]])
  end

  it 'should eval list comprehension variable override' do
    engine.parse defn('A:',
                      '    b = [b/2.0 for b in [1,2,3]]',
                     )
    expect(engine.evaluate('A', 'b')).to eq([0.5, 1.0, 1.5])
  end

  it 'should eval list comprehension variable override (2)' do
    engine.parse defn('A:',
                      '    a = 1',
                      '    b = [a+1 for a in [1,2,3]]',
                     )
    expect(engine.evaluate('A', 'b')).to eq([2, 3, 4])
  end

  it 'should eval conditional list comprehension' do
    engine.parse defn('A:',
                      '    b = [i*5 for i in [1,2,3,4,5] if i%2 == 1]',
                      '    c = [i/10.0 for i in [1,2,3,4,5] if i>4]',
                     )
    expect(engine.evaluate('A', 'b')).to eq([5, 15, 25])
    expect(engine.evaluate('A', 'c')).to eq([0.5])
  end

  it 'should handle list comprehension unpacking' do
    engine.parse defn('A:',
                      '    b = [a-b for a, b in [[1,2],[20,10]]]',
                     )
    expect(engine.evaluate('A', 'b')).to eq([-1, 10])
  end

  it 'should handle list comprehension with conditions using loop var' do
    skip 'need to fix'
    engine.parse defn('A:',
                      "    b = [n for n in {'pt' : 1} if n[1]+1]",
                     )
    expect(engine.evaluate('A', 'b')).to eq([['pt', 1]])
  end

  it 'should eval hashes' do
    engine.parse defn('A:',
                      '    b = {}',
                      "    c = {'a':1, 'b': 2,'c':3}",
                      "    d = {123*2: -123, 'b_b': 1+1}",
                      "    e = {'x': 1, 'y': 1+1, 'z': 1+1+1, 'zz': 1*2*4}",
                      "    f = {'a': nil, 'b': [1, nil, 2]}",
                      '    g = {b:b, [b]:[1,23], []:345}',
                     )

    expect(engine.evaluate('A', %w[b c d e f g])).to eq(
      [{},
       { 'a' => 1, 'b' => 2, 'c' => 3 },
       { 123 * 2 => -123, 'b_b' => 2 },
       { 'x' => 1, 'y' => 2, 'z' => 3, 'zz' => 8 },
       { 'a' => nil, 'b' => [1, nil, 2] },
       { {} => {}, [{}] => [1, 23], [] => 345 },
      ])
  end

  it 'handles literal hashes with conditionals' do
    engine.parse defn('A:',
                      "    a = {'a':1 if 123, 'b':'x' if nil}",
                      "    b = {'a':a if a, 2: a if true, 'c':nil if 2*2}",
                      '    c = 1>2',
                      '    d = {1: {1: 2 if b}, 3: 3 if c, 2: {2: 3 if a}}',
                     )

    expect(engine.evaluate('A', %w[a b d])).to eq([
                                                    { 'a' => 1 },
                                                    { 'a' => { 'a' => 1 }, 2 => { 'a' => 1 }, 'c' => nil },
                                                    { 1 => { 1 => 2 }, 2 => { 2 => 3 } },
                                                  ])
  end

  it 'should eval hash comprehension' do
    engine.parse defn('A:',
                      '    b = {i*5 :i for i in [1,2,3]}',
                      '    c = [kv for kv in {1:11, 2:22}]',
                     )
    expect(engine.evaluate('A', 'b')).to eq(5 => 1, 10 => 2, 15 => 3)
    expect(engine.evaluate('A', 'c')).to eq([[1, 11], [2, 22]])
  end

  it 'for-in-hash should iterate over key/value pairs' do
    engine.parse defn('A:',
                      '    b = {1: 11, 2: 22}',
                      '    c = [kv[0]-kv[1] for kv in b]',
                      '    d = {kv[0] : kv[1] for kv in b}',
                      '    e = [kv for kv in b if kv[1]]',
                      '    f = [k-v for k, v in b if k>1]',
                     )
    expect(engine.evaluate('A', 'c')).to eq([-10, -20])
    expect(engine.evaluate('A', 'd')).to eq(1 => 11, 2 => 22)
    expect(engine.evaluate('A', 'f')).to eq([-20])

    # FIXME: this is a known bug in Delorean caused by the strange way
    # that select iterates over hashes and provides args to the block.
    # engine.evaluate("A", "e").should == [[1,11], [2,22]]
  end

  it 'should eval nested hash comprehension' do
    engine.parse defn('A:',
                      '    b = { a:{a+c:a-c for c in [4,5]} for a in [1,2,3]}',
                     )
    expect(engine.evaluate('A', 'b')).to eq(
      1 => { 5 => -3, 6 => -4 },
      2 => { 6 => -2, 7 => -3 },
      3 => { 7 => -1, 8 => -2 }
    )
  end

  it 'should eval conditional hash comprehension' do
    engine.parse defn('A:',
                      '    b = {i*5:i+5 for i in [1,2,3,4,5] if i%2 == 1}',
                      '    c = {i/10.0:i*10 for i in [1,2,3,4,5] if i>4}',
                     )
    expect(engine.evaluate('A', 'b')).to eq(5 => 6, 15 => 8, 25 => 10)
    expect(engine.evaluate('A', 'c')).to eq(0.5 => 50)
  end

  it 'should eval hash methods such as length' do
    engine.parse defn('A:',
                      '    b = {}',
                      "    c = {'a':1, 'b': 2,'c':3}",
                      '    length1 = b.length',
                      '    length2 = c.length',
                     )

    expect(engine.evaluate('A', 'length1')).to eq(0)
    expect(engine.evaluate('A', 'length2')).to eq(3)
  end

  it 'should eval node calls as intermediate results' do
    engine.parse defn('A:',
                      '    a =?',
                      '    e = A(a=13)',
                      '    d = e.a * 2',
                      '    f = e.d / e.a',
                     )

    expect(engine.evaluate('A', ['d', 'f'])).to eq([26, 2])
  end

  it 'allows node calls from attrs' do
    engine.parse defn('A:',
                      '    a =?',
                      '    c =?',
                      '    b = a**2',
                      '    e = A(a=13)',
                      "    d = e(a=4, **{'c': 5})",
                      '    f = d.b + d.c + e().a',
                     )

    expect(engine.evaluate('A', ['f'])).to eq([16 + 5 + 13])
  end

  it 'should eval multi-var hash comprehension' do
    engine.parse defn('A:',
                      '    b = {k*5 : v+1 for k, v in {1:2, 7:-30}}',
                      '    c = [k-v for k, v in {1:2, 7:-30}]',
                     )
    expect(engine.evaluate('A', 'b')).to eq(5 => 3, 35 => -29)
    expect(engine.evaluate('A', 'c')).to eq([-1, 37])
  end

  it 'should be able to amend node calls' do
    engine.parse defn('A:',
                      '    a =?',
                      '    aa = a*2',
                      '    c = A(a=12)',
                      "    d = c+{'a':3}",
                      "    f = c+{'a':4}",
                      '    g = d.aa + f.aa',
                      '    h = c(a=5).aa',
                      '    j = d(a=6).aa',
                     )

    expect(engine.evaluate('A', ['g', 'h', 'j'])).to eq(
      [3 * 2 + 4 * 2, 5 * 2, 6 * 2]
    )
  end

  it 'should be able to amend node calls 2' do
    engine.parse defn('A:',
                      '    a =?',
                      '    d = A(a=3)',
                      '    e = [d.a, d(a=4).a]',
                     )

    expect(engine.evaluate('A', ['e'])).to eq([[3, 4]])
  end

  it 'should eval module calls 1' do
    engine.parse defn('A:',
                      '    a = 123',
                      '    n = A',
                      '    d = n().a',
                     )

    expect(engine.evaluate('A', %w[d])).to eq([123])
  end

  it 'should eval module calls 2' do
    engine.parse defn('A:',
                      '    a = 123',
                      '    b = 456 + a',
                      "    n = 'A'",
                      "    c = nil(x = 123, y = 456) % ['a', 'b']",
                      "    d = n(x = 123, y = 456) % ['a', 'b']",
                      "    e = nil() % ['b']",
                     )

    expect(engine.evaluate('A', %w[n c d e])).to eq(
      [
        'A',
        { 'a' => 123, 'b' => 579 },
        { 'a' => 123, 'b' => 579 },
        { 'b' => 579 }
      ])
  end

  it 'should eval module calls 3' do
    engine.parse defn('A:',
                      '    a = 123',
                      'B:',
                      "    n = 'A'",
                      '    d = n().a',
                     )

    expect(engine.evaluate('B', %w[d])).to eq([123])
  end

  it 'should be possible to implement recursive calls' do
    engine.parse defn('A:',
                      '    n =?',
                      '    fact = if n <= 1 then 1 else n * A(n=n-1).fact',
                     )

    expect(engine.evaluate('A', 'fact', 'n' => 10)).to eq(3_628_800)
  end

  it 'should eval module calls by node name' do
    engine.parse defn('A:',
                      '    a = 123',
                      '    b = A().a',
                     )
    expect(engine.evaluate('A', 'b')).to eq(123)
  end

  it 'should eval multiline expressions' do
    engine.parse defn('A:',
                      '    a = 1',
                      '    b = [a+1',
                      '        for a in [1,2,3]',
                      '        ]',
                     )
    expect(engine.evaluate('A', 'b')).to eq([2, 3, 4])
  end

  it 'should eval multiline expressions (2)' do
    engine.parse defn('A:',
                      '    a = 123',
                      '    b = 456 + ',
                      '        a',
                      "    n = 'A'",
                      '    c = nil(x = 123,',
                      "          y = 456) % ['a', 'b']",
                      '    d = n(',
                      "           x = 123, y = 456) % ['a', 'b']",
                      '    e = nil(',
                      "         ) % ['b']",
                     )

    expect(engine.evaluate('A', %w[n c d e])).to eq(
      [
        'A',
        { 'a' => 123, 'b' => 579 },
        { 'a' => 123, 'b' => 579 },
        { 'b' => 579 }
      ])
  end

  it 'should eval in expressions' do
    engine.parse defn('A:',
                      '    a = [1,2,3,33,44]',
                      '    s = {22,33,44}',
                      '    b = (1 in a) && (2 in {22,44})',
                      '    c = (2 in a) && (22 in s)',
                      '    d = [i*2 for i in s if i in a]',
                     )

    expect(engine.evaluate('A', %w[b c d])).to eq([false, true, [66, 88]])
  end

  it 'should eval imports' do
    engine.parse defn('import AAA',
                      'A:',
                      '    b = 456',
                      'B: AAA::X',
                      '    a = 111',
                      '    c = AAA::X(a=456).b',
                     )
    expect(engine.evaluate('B', ['a', 'b', 'c'], {})).to eq([111, 222, 456 * 2])
  end

  it 'should eval imports (2)' do
    sset.merge(
      'BBB' =>
      defn('import AAA',
           'B: AAA::X',
           '    a = 111',
           '    c = AAA::X(a=-1).b',
           '    d = a * 2',
          ),
      'CCC' =>
      defn('import BBB',
           'import AAA',
           'B: BBB::B',
           '    e = d * 3',
           'C: AAA::X',
           '    d = b * 3',
          ),
    )

    e2 = sset.get_engine('BBB')

    expect(e2.evaluate('B', ['a', 'b', 'c', 'd'])).to eq([111, 222, -2, 222])

    engine.parse defn('import BBB',
                      'B: BBB::B',
                      '    e = d + 3',
                     )

    expect(engine.evaluate('B', ['a', 'b', 'c', 'd', 'e'])).to eq(
      [111, 222, -2, 222, 225]
    )

    e4 = sset.get_engine('CCC')

    expect(e4.evaluate('B', ['a', 'b', 'c', 'd', 'e'])).to eq(
      [111, 222, -2, 222, 666]
    )

    expect(e4.evaluate('C', ['a', 'b', 'd'])).to eq([123, 123 * 2, 123 * 3 * 2])
  end

  it 'should eval imports (3)' do
    sset.merge(
      'BBB' => getattr_code,
      'CCC' =>
      defn('import BBB',
           'X:',
           '    xx = [n.x for n in BBB::D().xs]',
           '    yy = [n.x for n in BBB::D.xs]',
          ),
    )

    e4 = sset.get_engine('CCC')
    expect(e4.evaluate('X', 'xx')).to eq([1, 2, 3])
    expect(e4.evaluate('X', 'yy')).to eq([1, 2, 3])
  end

  it 'should eval imports (4) - with ::' do
    sset.merge(
      'BBB' => getattr_code,
      'BBB::A' => defn(
        'X:',
        '    xx = [1, 2, 3]'
      ),
      'BBB::A::CC' => defn(
        'X:',
        '    xx = [1, 2, 3]'
      ),
      'DDD__Ef__Gh' => defn(
        'import BBB',
        'import BBB::A',
        'import BBB::A::CC',
        'EfNode:',
        '    g = BBB::D.xs',
        '    gh = BBB::A::X.xx',
      ),
      'CCC' =>
      defn('import BBB',
           'import DDD__Ef__Gh',
           'X:',
           '    xx = [n.x for n in BBB::D().xs]',
           '    yy = [n.x for n in BBB::D.xs]',
           '    zz = [n * 2 for n in DDD__Ef__Gh::EfNode.gh]',
          ),
    )

    e4 = sset.get_engine('CCC')
    expect(e4.evaluate('X', 'xx')).to eq([1, 2, 3])
    expect(e4.evaluate('X', 'zz')).to eq([2, 4, 6])
  end

  it 'should eval imports (4) - inheritance - with ::' do
    sset.merge(
      'BBB' => getattr_code,
      'BBB::A' => defn(
        'X:',
        '    xx = [1, 2, 3]'
      ),
      'BBB::A::CC' => defn(
        'X:',
        '    xx = [1, 2, 3]'
      ),
      'DDD__Ef__Gh' => defn(
        'import BBB',
        'import BBB::A',
        'import BBB::A::CC',
        'EfNode: BBB::A::CC::X',
        '    g = xx',
      ),
      'CCC' =>
      defn('import BBB',
           'import DDD__Ef__Gh',
           'X:',
           '    zz = [n * 2 for n in DDD__Ef__Gh::EfNode.g]',
          ),
    )

    e4 = sset.get_engine('CCC')
    expect(e4.evaluate('X', 'zz')).to eq([2, 4, 6])
  end

  it 'can eval indexing' do
    engine.parse defn('A:',
                      '    a = [1,2,3]',
                      '    b = a[1]',
                      '    c = a[-1]',
                      "    d = {'a' : 123, 'b': 456}",
                      "    e = d['b']",
                      '    f = a[1,2]',
                     )
    r = engine.evaluate('A', ['b', 'c', 'e', 'f'])
    expect(r).to eq([2, 3, 456, [2, 3]])
  end

  it 'can eval indexing 2' do
    engine.parse defn('A:',
                      '    a = 1',
                      "    b = {'x' : 123, 'y': 456}",
                      "    c = A() % ['a', 'b']",
                      "    d = c['b'].x * c['a'] - c['b'].y",
                     )
    r = engine.evaluate('A', ['a', 'b', 'c', 'd'])
    expect(r).to eq(
      [
        1,
        { 'x' => 123, 'y' => 456 },
        { 'a' => 1, 'b' => { 'x' => 123, 'y' => 456 } },
        -333
      ])
  end

  it 'can handle exceptions with / syntax' do
    engine.parse defn('A:',
                      '    a = 1',
                      "    b = {'x' : 123, 'y': 456}",
                      "    e = ERR('hello')",
                      "    c = A() / ['a', 'b']",
                      "    d = A() / ['a', 'e']",
                      "    f = A() / 'a'",
                     )
    r = engine.evaluate('A', ['a', 'b', 'c'])
    expect(r).to eq(
      [
        1,
        { 'x' => 123, 'y' => 456 },
        { 'a' => 1, 'b' => { 'x' => 123, 'y' => 456 } }
      ])

    r = engine.evaluate('A', ['a', 'd'])
    expect(r).to eq(
      [
        1,
        { 'error' => 'hello', 'backtrace' => [['XXX', 4, 'e'], ['XXX', 6, 'd']] }
      ])

    r = engine.evaluate('A', ['f'])
    expect(r).to eq([1])
  end

  it 'should properly eval overridden attrs' do
    engine.parse defn('A:',
                      '    a = 5',
                      '    b = a',
                      'B: A',
                      '    a = 2',
                      '    x = A.b - B.b',
                      '    k = [A.b, B.b]',
                      '    l = [x.b for x in [A, B]]',
                      '    m = [x().b for x in [A, B]]',
                     )

    expect(engine.evaluate('A', 'b')).to eq(5)
    expect(engine.evaluate('B', 'b')).to eq(2)
    expect(engine.evaluate('B', 'x')).to eq(3)
    expect(engine.evaluate('B', 'k')).to eq([5, 2])
    expect(engine.evaluate('B', 'l')).to eq([5, 2])
    expect(engine.evaluate('B', 'm')).to eq([5, 2])
  end

  it 'implements simple version of self (_)' do
    engine.parse defn('B:',
                      '    a =?',
                      '    b =?',
                      '    x = a - b',
                      'A:',
                      '    a =?',
                      '    b =?',
                      '    x = _.a * _.b',
                      '    y = a && _',
                      '    z = (B() + _).x',
                      '    w = B(**_).x',
                      "    v = {**_, 'a': 123}",
                     )

    expect(engine.evaluate('A', 'x', 'a' => 3, 'b' => 5)).to eq(15)
    h = { 'a' => 1, 'b' => 2, 'c' => 3 }
    expect(engine.evaluate('A', 'y', 'a' => 1, 'b' => 2, 'c' => 3)).to eq(h)
    expect(engine.evaluate('A', 'z', 'a' => 1, 'b' => 2, 'c' => 3)).to eq(-1)
    expect(engine.evaluate('A', 'w', 'a' => 4, 'b' => 5, 'c' => 3)).to eq(-1)
    expect(engine.evaluate('A', 'v', 'a' => 4, 'b' => 5, 'c' => 3)).to eq(
      'a' => 123, 'b' => 5, 'c' => 3
    )
  end

  it 'implements positional args in node calls' do
    engine.parse defn('B:',
                      '    a =?',
                      '    b =?',
                      '    x = (_.0 - _.1) * (a - b)',
                      '    y = [_.0, _.1, _.2]',
                      'A:',
                      '    a = _.0 - _.1',
                      '    z = B(10, 20, a=3, b=7).x',
                      "    y = B('x', 'y').y",
                     )
    expect(engine.evaluate('A', ['a', 'z', 'y'], 0 => 123, 1 => 456)).to eq(
      [123 - 456, 40, ['x', 'y', nil]]
    )
  end

  it 'can call 0-arity functions in list comprehension' do
    engine.parse defn('A:',
                      '    b = [x.name for x in Dummy.all_of_me]',
                     )
    r = engine.evaluate('A', 'b')
    expect(r).to eq ['hello']
  end

  it 'node calls are not memoized/cached' do
    engine.parse defn('A:',
                      '    x = Dummy.side_effect',
                      'B: A',
                      '    x = (A() + _).x + (A() + _).x'
                     )
    r = engine.evaluate('B', 'x')
    expect(r).to eq 3
  end

  it 'node calls with double splats' do
    engine.parse defn('A:',
                      '    a =?',
                      '    b =?',
                      '    c = a+b',
                      "    h = {'a': 123}",
                      "    k = {'b': 456}",
                      '    x = A(**h, **k).c'
                     )
    r = engine.evaluate('A', 'x')
    expect(r).to eq 579
  end

  it 'hash literal with double splats' do
    engine.parse defn('A:',
                      '    a =?',
                      '    b =?',
                      "    h = {'a': 123, **a}",
                      "    k = {'b': 456, **h, **a, **b}",
                      '    l = {**k}',
                      '    m = {**k, 1:1, 2:2, 3:33}',
                      '    n = {**k if false, 1:1, 2:2, 3:33}',
                     )
    r = engine.evaluate(
      'A',
      ['h', 'k', 'l', 'm', 'n'],
      'a' => { 3 => 3, 4 => 4 }, 'b' => { 5 => 5, 'a' => 'aa' }
    )

    expect(r).to eq [
      { 'a' => 123, 3 => 3, 4 => 4 },
      { 'b' => 456, 'a' => 'aa', 3 => 3, 4 => 4, 5 => 5 },
      { 'b' => 456, 'a' => 'aa', 3 => 3, 4 => 4, 5 => 5 },
      { 'b' => 456, 'a' => 'aa', 3 => 33, 4 => 4, 5 => 5, 1 => 1, 2 => 2 },
      { 1 => 1, 2 => 2, 3 => 33 },
    ]
  end

  it 'understands openstructs' do
    engine.parse defn('A:',
                      '    os = Dummy.returns_openstruct',
                      '    abc = os.abc',
                      '    not_found = os.not_found'
                     )
    r = engine.evaluate('A', ['os', 'abc', 'not_found'])
    expect(r[0].abc).to eq('def')
    expect(r[1]).to eq('def')
    expect(r[2]).to be_nil
  end

  it 'can use nodes as continuations' do
    # FIME: This is actually a trivial exmaple. Ideally we should be
    # able to pass arguments to the nodes when evaluating ys.  If the
    # arguments do not change the computation of "x" then "x" should
    # not be recomputed.  This would need some flow analysis though.

    engine.parse defn('A:',
                      '    a =?',
                      '    x = Dummy.side_effect',
                      '    y = x*a',
                      'B:',
                      '    ns = [A(a=a) for a in [1, 1, 1]]',
                      '    xs = [n.x for n in ns]',
                      '    ys = [n.y for n in ns]',
                      '    res = [xs, ys]',
                     )
    r = engine.evaluate('B', 'res')
    expect(r[1]).to eq r[0]
  end

  it 'can use nodes as continuations -- simple' do
    engine.parse defn('A:',
                      '    x = Dummy.side_effect',
                      '    y = x',
                      'B:',
                      '    ns = A()',
                      '    res = [ns.x, ns.y]',
                      "    res2 = ns % ['x', 'y']",
                     )
    r = engine.evaluate('B', 'res')
    expect(r[1]).to eq r[0]

    # this one works as expected
    r2 = engine.evaluate('B', 'res2')
    expect(r2.values.uniq.length).to eq 1
  end

  it 'Implements ability to use overridden superclass attrs' do
    code = <<-DELOREAN
    A:
        x = 123
        y = x*2
    B: A
        x = 5
        y = _sup.y * 10
        xx = _sup.x + 5
        yy = _sup.x * 10
    DELOREAN

    engine.parse code.gsub(/^    /, '')

    r = engine.evaluate('B', ['x', 'y', 'xx', 'yy'])
    expect(r).to eq [5, 2460, 128, 1230]
  end

  it 'works with the weird if case' do
    engine.parse defn('A:',
                      '    a = 1',
                      '    b = 1',
                      '    c = nil',
                      '    d = a || if b || c then 999 else 0',
                     )
    r = engine.evaluate('A', 'd')
    expect(r).to eq 1
  end

  it 'allows to close the bracket with the same spacing as variable' do
    engine.parse defn('A:',
                      '    a = [',
                      '        1,',
                      '        2,',
                      '    ]',
                      '    b = 2',
                     )
    r = engine.evaluate('A', 'a')
    expect(r).to eq [1, 2]

    r = engine.evaluate('A', 'b')
    expect(r).to eq 2
  end

  it 'allows to close the bracket with the same spacing as variable 2' do
    engine.parse defn('A:',
                      '    a = [',
                      '        {',
                      '          "a": 1,',
                      '          "b": 2,',
                      '        },',
                      '        2,',
                      '    ]',
                     )
    r = engine.evaluate('A', 'a')
    expect(r).to eq [{ 'a' => 1, 'b' => 2 }, 2]
  end

  it 'allows to close the bracket with the same spacing as variable 3' do
    engine.parse defn('A:',
                      '    a = {',
                      '      "a": 1,',
                      '      "b": 2,',
                      '    }',
                      '    b = 2',
                     )
    r = engine.evaluate('A', 'a')
    expect(r).to eq('a' => 1, 'b' => 2)

    r = engine.evaluate('A', 'b')
    expect(r).to eq 2
  end

  it 'allows to close the bracket with the same spacing as variable 4' do
    engine.parse defn('A:',
                      '    a = {',
                      '      "a": 1,',
                      '      "b": 2,',
                      '    }',
                      '    b = [1, 2]',
                      '    c = [',
                      '      {',
                      '        key : value + num',
                      '        for key, value in a',
                      '      }',
                      '      for num in b',
                      '    ]',
                     )
    r = engine.evaluate('A', 'c')
    expect(r).to eq([{ 'a' => 2, 'b' => 3 }, { 'a' => 3, 'b' => 4 }])
  end

  it 'allows to close the bracket with the same spacing as variable 5' do
    engine.parse defn('A:',
                      '    a = (',
                      '      1 +',
                      '      2',
                      '    )',
                      '    b = 2',
                     )
    r = engine.evaluate('A', 'a')
    expect(r).to eq(3)

    r = engine.evaluate('A', 'b')
    expect(r).to eq 2
  end

  describe 'blocks' do
    let(:default_node) do
      ['A:',
       '    array = [1, 2, 3]',
       "    hash = {'a': 1, 'b': 2, 'c': 3}",
      ]
    end

    it 'evaluates on arrays' do
      engine.parse defn(*default_node,
                        '    b = array.any()',
                        '        item =?',
                        '        result = item > 10',
                        '    c = array.any()',
                        '        x =?',
                        '        result = x > 1',
                        '    d = array.select',
                        '        x =?',
                        '        result = x > 1',
                        '    e = array.any',
                        '        item =?',
                        '        result = item > 10',
                        '    f = array.any',
                        '        x =?',
                        '        result = x > 1',
                        '    g = array.any?',
                        '        result = nil',
                        '    h = array.any',
                        '        result = nil',
                       )

      r = engine.evaluate('A', 'b')
      expect(r).to eq(false)

      r = engine.evaluate('A', 'c')
      expect(r).to eq(true)

      r = engine.evaluate('A', 'd')
      expect(r).to eq([2, 3])

      r = engine.evaluate('A', 'e')
      expect(r).to eq(false)

      r = engine.evaluate('A', 'f')
      expect(r).to eq(true)

      r = engine.evaluate('A', 'g')
      expect(r).to eq(false)
    end

    it 'works with question mark in methods' do
      engine.parse defn(*default_node,
                        '    b = array.any?',
                        '        item =?',
                        '        result = item > 10',
                       )
      r = engine.evaluate('A', 'b')
      expect(r).to eq(false)
    end

    it 'raises parse error if result formula is not present in block' do
      expect do
        engine.parse defn(*default_node,
                          '    b = array.any?',
                          '        item =?',
                          '        wrong = item > 10',
                         )
      end.to raise_error(
        Delorean::ParseError,
        /result formula is required in blocks/
      )
    end

    # it 'chains method calls on block' do
    # engine.parse defn(*default_node,
    # '    b = array.select { |b| b > 2 }.last',
    # '    c = array.select { |b| ',
    # '        b > 2 ||',
    # '        b <= 1 ',
    # '        }.first',
    # )
    #
    # r = engine.evaluate('A', 'b')
    # expect(r).to eq(3)
    #
    # r = engine.evaluate('A', 'c')
    # expect(r).to eq(1)
    # end

    it 'evaluates on hashes' do
      engine.parse defn(*default_node,
                        '    b = hash.any()',
                        '        key =?',
                        '        val =?',
                        '        result = val > 10',
                        '    c = hash.any()',
                        '        key =?',
                        '        val =?',
                        '        result = val > 2',
                        '    d = hash.select()',
                        '        key =?',
                        '        val =?',
                        "        result = key == 'a' || val == 2",
                        '    e = hash.select()',
                        '        key =?',
                        '        val =?',
                        "        result = key == 'c' || key == 'b'",
                       )

      r = engine.evaluate('A', 'b')
      expect(r).to eq(false)

      r = engine.evaluate('A', 'c')
      expect(r).to eq(true)

      r = engine.evaluate('A', 'd')
      expect(r).to eq('a' => 1, 'b' => 2)

      r = engine.evaluate('A', 'e')
      expect(r).to eq('b' => 2, 'c' => 3)
    end

    it 'whitelisting still works inside of block' do
      engine.parse defn(*default_node,
                        '    b = array.any()',
                        '        item =?',
                        '        result = array[1] != 2',
                        '    c = array.any()',
                        '        x =?',
                        '        result = ActiveRecord::Base.all()',
                        '    d = array.reject',
                        '    e = d.with_index()',
                        '        v =?',
                        '        result = nil',
                       )

      r = engine.evaluate('A', 'b')
      expect(r).to eq(false)

      expect { engine.evaluate('A', 'c') }.to raise_error(
        RuntimeError, 'no such method all'
      )

      expect { engine.evaluate('A', 'e') }.to raise_error(
        RuntimeError, 'no such method with_index'
      )
    end

    it 'variables in blocks do not overwrite external variables' do
      engine.parse defn(*default_node,
                        '    b = 1',
                        '    c = 2',
                        '    d = array.select',
                        '        b =?',
                        '        result = b + c',
                       )

      r = engine.evaluate('A', ['d', 'b', 'c'])
      expect(r).to eq([[1, 2, 3], 1, 2])
    end

    it 'works with default block parameter values' do
      engine.parse defn(*default_node,
                        '    b = 1',
                        '    d = array.select',
                        '        b =?',
                        '        c =? 2',
                        '        result = b > c',
                       )

      r = engine.evaluate('A', ['d', 'b'])
      expect(r).to eq([[3], 1])
    end

    it 'works with custom formulas in blocks' do
      engine.parse defn(*default_node,
                        '    a = 1',
                        '    b = 1',
                        '    c = array.select     ',
                        '        b =? 1',
                        '        base_result = (b + a) > 2',
                        '        base_result2 = base_result || false',
                        '        result = base_result2',
                        '    result = 10',
                       )
      r = engine.evaluate('A', 'c')
      expect(r).to eq([2, 3])

      r = engine.evaluate('A', 'result')
      expect(r).to eq(10)
    end

    it 'block parameter can reference another block parameter or outside var' do
      engine.parse defn(*default_node,
                        '    a = 1',
                        '    ab = 1',
                        '    b = 1',
                        '    c = array.select     ',
                        '        b =? 1',
                        '        ab =? b + a - 1',
                        '        result = ab > 2',
                        '    result = 10',
                       )
      r = engine.evaluate('A', 'c')
      expect(r).to eq([3])

      r = engine.evaluate('A', ['c', 'ab'])
      expect(r).to eq([[3], 1])
    end

    it 'works with syntax in blocks' do
      engine.parse defn(*default_node,
                        '    b = 1',
                        '    c = array.select     ',
                        '        b =? 1',
                        '        result = b > 2',
                        '    d = array.select     ',
                        '        b =?',
                        '        result = b > 2',
                        '    e = array.select     ',
                        '        result = b > 2',
                        '        t = 1',
                        '    f = 3'
                       )

      r = engine.evaluate('A', 'c')
      expect(r).to eq([3])

      r = engine.evaluate('A', 'd')
      expect(r).to eq([3])

      r = engine.evaluate('A', 'e')
      expect(r).to eq([])

      r = engine.evaluate('A', ['e', 'b'])
      expect(r).to eq([[], 1])
    end

    it 'works with safe navigation' do
      engine.parse defn(*default_node,
                        '    b = [1]',
                        '    c = b[1]    ',
                        '    d = c&.round(1)     ',
                        '    e = c&.round     ',
                        '    f = c&.round(1)&.round(2)&.round(3)     ',
                        '    g = c&.round&.round&.round     ',
                       )

      r = engine.evaluate('A', 'd')
      expect(r).to eq(nil)

      r = engine.evaluate('A', 'e')
      expect(r).to eq(nil)

      r = engine.evaluate('A', 'f')
      expect(r).to eq(nil)

      r = engine.evaluate('A', 'g')
      expect(r).to eq(nil)
    end

    describe 'methods' do
      it 'all?' do
        engine.parse defn(*default_node,
                          '    b = array.all?',
                          '        num =?',
                          '        result = num > 1',
                          '    c = hash.all?',
                          '        key =?',
                          '        val =?',
                          '        result = key.length() == 1',
                         )

        r = engine.evaluate('A', 'b')
        expect(r).to eq(false)

        r = engine.evaluate('A', 'c')
        expect(r).to eq(true)
      end

      it 'any?' do
        engine.parse defn(*default_node,
                          '    b = array.any?',
                          '        num =?',
                          '        result = num > 4',
                          '    c = hash.any?',
                          '        key =?',
                          '        val =?',
                          '        result = val >= 2',
                         )

        r = engine.evaluate('A', 'b')
        expect(r).to eq(false)

        r = engine.evaluate('A', 'c')
        expect(r).to eq(true)
      end

      it 'find' do
        engine.parse defn(*default_node,
                          '    b = array.find',
                          '        num =?',
                          '        result = num == 2',
                          '    c = hash.find',
                          '        key =?',
                          '        val =?',
                          '        result = key == "b"',
                         )

        r = engine.evaluate('A', 'b')
        expect(r).to eq(2)

        r = engine.evaluate('A', 'c')
        expect(r).to eq(['b', 2])
      end

      it 'max_by' do
        engine.parse defn(*default_node,
                          '    b = array.max_by',
                          '        num =?',
                          '        result = - num',
                          '    c = hash.max_by',
                          '        key =?',
                          '        val =?',
                          '        result = val',
                         )

        r = engine.evaluate('A', 'b')
        expect(r).to eq(1)

        r = engine.evaluate('A', 'c')
        expect(r).to eq(['c', 3])
      end

      it 'min_by' do
        engine.parse defn(*default_node,
                          '    b = array.min_by',
                          '        num =?',
                          '        result = - num',
                          '    c = hash.min_by',
                          '        key =?',
                          '        val =?',
                          '        result = val',
                         )

        r = engine.evaluate('A', 'b')
        expect(r).to eq(3)

        r = engine.evaluate('A', 'c')
        expect(r).to eq(['a', 1])
      end

      it 'none?' do
        engine.parse defn(*default_node,
                          '    b = array.none?',
                          '        num =?',
                          '        result = num > 4',
                          '    c = hash.none?',
                          '        key =?',
                          '        val =?',
                          '        result = val >= 2',
                         )

        r = engine.evaluate('A', 'b')
        expect(r).to eq(true)

        r = engine.evaluate('A', 'c')
        expect(r).to eq(false)
      end

      it 'reduce' do
        engine.parse defn(*default_node,
                          '    b = array.reduce(2)',
                          '        sum =?',
                          '        num =?',
                          '        result = sum + num',
                          '    b2= array.reduce',
                          '        sum =?',
                          '        num =?',
                          '        result = sum + num',
                          '    c = hash.reduce(2)',
                          '        sum =?',
                          '        key_val =?',
                          '        result = sum + key_val[1]',
                          '    c2 = hash.reduce([0])',
                          '        sum =?',
                          '        key_val =?',
                          '        result = [sum.last + key_val[1]]',
                         )

        r = engine.evaluate('A', 'b')
        expect(r).to eq(8)

        r = engine.evaluate('A', 'b2')
        expect(r).to eq(6)

        r = engine.evaluate('A', 'c')
        expect(r).to eq(8)

        r = engine.evaluate('A', 'c2')
        expect(r).to eq([6])
      end

      it 'reject' do
        engine.parse defn(*default_node,
                          '    b = array.reject',
                          '        num =?',
                          '        result = num >= 2',
                          '    c = hash.reject',
                          '        key =?',
                          '        val =?',
                          '        result = val > 2',
                         )

        r = engine.evaluate('A', 'b')
        expect(r).to eq([1])

        r = engine.evaluate('A', 'c')
        expect(r).to eq('a' => 1, 'b' => 2)
      end

      it 'uniq' do
        engine.parse defn(*default_node,
                          '    b = array.uniq',
                          '        num =?',
                          '        result = (num / 3.0).round',
                          '    b2 = array.uniq',
                          '    c = hash.uniq',
                          '        key =?',
                          '        val =?',
                          '        result = if key == "b" then "a" else key',
                          '    c2 = hash.uniq',
                         )

        r = engine.evaluate('A', 'b')
        expect(r).to eq([1, 2])

        r = engine.evaluate('A', 'b2')
        expect(r).to eq([1, 2, 3])

        r = engine.evaluate('A', 'c')
        expect(r).to eq([['a', 1], ['c', 3]])

        r = engine.evaluate('A', 'c2')
        expect(r).to eq([['a', 1], ['b', 2], ['c', 3]])
      end
    end
  end
end
