# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'Delorean' do
  let(:engine) do
    Delorean::Engine.new('ZZZ')
  end

  it 'should handle MAX as a node name' do
    engine.parse defn('MAX:',
                      '    a = [1, 2, 3, 0, -10].max()',
                     )

    r = engine.evaluate('MAX', 'a')
    expect(r).to eq(3)
  end

  it 'should handle COMPACT' do
    engine.parse defn('A:',
                      '    a = [1, 2, nil, -3, 4].compact',
                      "    b = {'a': 1, 'b': nil, 'c': nil}.compact()",
                     )

    expect(engine.evaluate('A', 'a')).to eq([1, 2, -3, 4])
    expect(engine.evaluate('A', 'b')).to eq('a' => 1)
  end

  it 'should handle MIN' do
    engine.parse defn('A:',
                      '    a = [1, 2, -3, 4].min()',
                     )

    r = engine.evaluate('A', 'a')
    expect(r).to eq(-3)
  end

  it 'should handle ROUND' do
    engine.parse defn('A:',
                      '    a = 12.3456.round(2)',
                      '    b = 12.3456.round(1)',
                      '    c = 12.3456.round()',
                     )

    r = engine.evaluate('A', ['a', 'b', 'c'])
    expect(r).to eq([12.35, 12.3, 12])
  end

  it 'should handle TRUNCATE' do
    engine.parse defn('A:',
                      '    a = 12.3456.truncate(2)',
                      '    b = 12.3456.truncate(1)',
                      '    c = 12.3456.truncate()',
                     )

    r = engine.evaluate('A', ['a', 'b', 'c'])
    expect(r).to eq([12.34, 12.3, 12])
  end

  it 'should handle FLOOR' do
    engine.parse defn('A:',
                      '    a = [12.3456.floor(), 13.7890.floor()]',
                     )

    r = engine.evaluate('A', 'a')
    expect(r).to eq([12, 13])
  end

  it 'should handle TO_F' do
    engine.parse defn('A:',
                      '    a = 12.3456.to_f()',
                      "    b = '12.3456'.to_f()",
                      "    c = '12'.to_f()",
                      "    d = '2018-05-04 10:56:27 -0700'.to_time.to_f",
                     )

    r = engine.evaluate('A', ['a', 'b', 'c', 'd'])
    expect(r).to eq([12.3456, 12.3456, 12, 1_525_456_587.0])
  end

  it 'should handle ABS' do
    engine.parse defn('A:',
                      '    a = (-123).abs()',
                      '    b = (-1.1).abs()',
                      '    c = 2.3.abs()',
                      '    d = 0.abs()',
                     )

    r = engine.evaluate('A', ['a', 'b', 'c', 'd'])
    expect(r).to eq([123, 1.1, 2.3, 0])
  end

  it 'should handle STRING' do
    engine.parse defn('A:',
                      "    a = 'hello'.to_s()",
                      '    b = 12.3456.to_s()',
                      '    c = [1,2,3].to_s()',
                     )

    r = engine.evaluate('A', ['a', 'b', 'c'])
    expect(r).to eq(['hello', '12.3456', [1, 2, 3].to_s])
  end

  it 'should handle FETCH' do
    engine.parse defn('A:',
                      "    h = {'a':123, 1:111}",
                      "    a = h.fetch('a')",
                      '    b = h.fetch(1)',
                      "    c = h.fetch('xxx', 456)",
                     )

    r = engine.evaluate('A', ['a', 'b', 'c'])
    expect(r).to eq([123, 111, 456])
  end

  it 'should handle TIMEPART' do
    engine.parse defn('A:',
                      '    p =?',
                      '    h = p.hour()',
                      '    m = p.min()',
                      '    s = p.sec()',
                      '    d = p.to_date()',
                      '    e = p.to_date.to_s.to_date',
                     )

    p = Time.now
    params = { 'p' => p }
    r = engine.evaluate('A', %w[h m s d e], params)
    expect(r).to  eq([p.hour, p.min, p.sec, p.to_date, p.to_date])

    # Non time argument should raise an error
    expect { engine.evaluate('A', ['m'], 'p' => 123) }.to raise_error(RuntimeError)
  end

  it 'should handle DATEPART' do
    engine.parse defn('A:',
                      '    p =?',
                      '    y = p.year()',
                      '    d = p.day()',
                      '    m = p.month()',
                     )

    p = Date.today
    r = engine.evaluate('A', ['y', 'd', 'm'], 'p' => p)
    expect(r).to eq([p.year, p.day, p.month])

    # Non date argument should raise an error
    expect do
      engine.evaluate('A', ['y', 'd', 'm'], 'p' => 123)
    end.to raise_error(RuntimeError)
  end

  it 'should handle FLATTEN' do
    x = [[1, 2, [3]], 4, 5, [6]]

    engine.parse defn('A:',
                      "    a = #{x}",
                      '    b = a.flatten() + a.flatten(1)'
                     )

    expect(engine.evaluate('A', 'b')).to eq(x.flatten + x.flatten(1))
  end

  it 'should handle ZIP' do
    a = [1, 2]
    b = [4, 5, 6]
    c = [7, 8]

    engine.parse defn('A:',
                      "    a = #{a}",
                      "    b = #{b}",
                      "    c = #{c}",
                      '    d = a.zip(b) + a.zip(b, c)',
                     )

    expect(engine.evaluate('A', 'd')).to eq(a.zip(b) + a.zip(b, c))
  end

  it 'should handle ERR' do
    engine.parse defn('A:',
                      "    a = ERR('hello')",
                      "    b = ERR('xx', 1, 2, 3)",
                     )

    expect { engine.evaluate('A', 'a') }.to raise_error('hello')

    expect { engine.evaluate('A', 'b') }.to raise_error('xx, 1, 2, 3')
  end

  it 'should handle RUBY' do
    x = [[1, 2, [-3]], 4, 5, [6], -3, 4, 5, 0]

    engine.parse defn('A:',
                      "    a = #{x}",
                      '    b = a.flatten()',
                      '    c = a.flatten(1)',
                      '    d = b+c',
                      '    dd = d.flatten()',
                      '    e = dd.sort()',
                      '    f = e.uniq()',
                      '    g = e.length',
                      '    gg = a.length()',
                      '    l = a.member(5)',
                      '    m = [a.member(5), a.member(55)]',
                      "    n = {'a':1, 'b':2, 'c':3}.length()",
                      "    o = 'hello'.length",
                     )

    expect(engine.evaluate('A', 'c')).to eq(x.flatten(1))
    expect(engine.evaluate('A', 'd')).to eq(x.flatten + x.flatten(1))
    dd = engine.evaluate('A', 'dd')
    expect(engine.evaluate('A', 'e')).to eq(dd.sort)
    expect(engine.evaluate('A', 'f')).to eq(dd.sort.uniq)
    expect(engine.evaluate('A', 'g')).to eq(dd.length)
    expect(engine.evaluate('A', 'gg')).to eq(x.length)
    expect(engine.evaluate('A', 'm')).to eq([x.member?(5), x.member?(55)])
    expect(engine.evaluate('A', 'n')).to eq(3)
    expect(engine.evaluate('A', 'o')).to eq(5)
  end

  it 'should be able to call function on hash' do
    engine.parse defn('A:',
                      "    m = {'length':100}.length",
                      '    n = {}.length',
                      '    o = {}["length"]',
                     )
    expect(engine.evaluate('A', 'n')).to eq(0)
    expect(engine.evaluate('A', 'm')).to eq(100)
    expect(engine.evaluate('A', 'o')).to be_nil
  end

  it 'should be able to call hash except' do
    engine.parse defn('A:',
                      "    h = {'a': 1, 'b':2, 'c': 3}",
                      "    e = h.except('a', 'c')",
                     )
    expect(engine.evaluate('A', 'e')).to eq('b' => 2)
  end

  it 'should handle RUBY slice function' do
    x = [[1, 2, [-3]], 4, [5, 6], -3, 4, 5, 0]

    engine.parse defn('A:',
                      "    a = #{x}",
                      '    b = a.slice(0, 4)',
                     )
    expect(engine.evaluate('A', 'b')).to eq(x.slice(0, 4))
  end

  it 'should handle RUBY empty? function' do
    engine.parse defn('A:',
                      '    a0 = []',
                      '    b0 = {}',
                      '    c0 = {-}',
                      '    a1 = [1,2,3]',
                      "    b1 = {'a': 1, 'b':2}",
                      '    c1 = {1,2,3}',
                      '    res = [a0.empty, b0.empty(), c0.empty, a1.empty, b1.empty(), c1.empty]',
                     )
    expect(engine.evaluate('A', 'res')).to eq(
      [true, true, true, false, false, false]
    )
  end

  it 'should handle BETWEEN' do
    engine.parse defn('A:',
                      '    a = 1.23',
                      '    number_between = [a.between(10,20), a.between(1,3)]',
                      "    c = 'c'",
                      "    string_between = [c.between('a', 'd'), c.between('d', 'e')]",
                      "    types_mismatch1 = [a.between('a', 'd')]",
                      '    types_mismatch2 = [c.between(1, 3)]'
                     )

    expect(engine.evaluate('A', 'number_between')).to eq([false, true])
    expect(engine.evaluate('A', 'string_between')).to eq([true, false])

    expect { engine.evaluate('A', 'types_mismatch1') }.to raise_error(/bad arg/)
    expect { engine.evaluate('A', 'types_mismatch2') }.to raise_error(/bad arg/)
  end

  it 'should handle MATCH' do
    engine.parse defn('A:',
                      "    a = 'this is a test'.match('(.*)( is )(.*)')",
                      '    b = [a[0], a[1], a[2], a[3], a[4]]',
                     )

    expect(engine.evaluate('A', 'b'))
      .to eq(['this is a test', 'this', ' is ', 'a test', nil])
  end
end
