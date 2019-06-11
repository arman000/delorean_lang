# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'Delorean' do
  let(:engine) do
    Delorean::Engine.new('YYY')
  end

  it 'can enumerate nodes' do
    engine.parse defn('X:',
                      '    a = 123',
                      '    b = a',
                      'Y: X',
                      'A:',
                      'XX: Y',
                      '    a = 11',
                      '    c =?',
                      '    d = 456',
                     )
    expect(engine.enumerate_nodes).to eq(SortedSet.new(['A', 'X', 'XX', 'Y']))
  end

  it 'can enumerate attrs by node' do
    engine.parse defn('X:',
                      '    a = 123',
                      '    b = a',
                      'Y: X',
                      'Z:',
                      'XX: Y',
                      '    a = 11',
                      '    c =?',
                      '    d = 456',
                     )

    exp = {
      'X' => ['a', 'b'],
      'Y' => ['a', 'b'],
      'Z' => [],
      'XX' => ['a', 'b', 'c', 'd'],
    }
    res = engine.enumerate_attrs

    expect(res.keys.sort).to eq(exp.keys.sort)

    exp.each do |k, v|
      expect(engine.enumerate_attrs_by_node(k).sort).to eq(v)
      expect(res[k].sort).to eq(v)
    end
  end

  it 'can enumerate params' do
    engine.parse defn('X:',
                      '    a =? 123',
                      '    b = a',
                      'Y: X',
                      'Z:',
                      'XX: Y',
                      '    a = 11',
                      '    c =?',
                      '    d = 123',
                      'YY: XX',
                      '    c =? 22',
                      '    e =? 11',
                     )

    expect(engine.enumerate_params).to eq(Set.new(['a', 'c', 'e']))
  end

  it 'can enumerate params by node' do
    engine.parse defn('X:',
                      '    a =? 123',
                      '    b = a',
                      'Y: X',
                      'Z:',
                      'XX: Y',
                      '    a = 11',
                      '    c =?',
                      '    d = 123',
                      'YY: XX',
                      '    c =? 22',
                      '    e =? 11',
                     )
    expect(engine.enumerate_params_by_node('X')).to eq(Set.new(['a']))
    expect(engine.enumerate_params_by_node('XX')).to eq(Set.new(['a', 'c']))
    expect(engine.enumerate_params_by_node('YY')).to eq(Set.new(['a', 'c', 'e']))
    expect(engine.enumerate_params_by_node('Z')).to eq(Set.new([]))
  end
end
