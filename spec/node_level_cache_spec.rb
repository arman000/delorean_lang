# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'Node level caching' do
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
    eng = Delorean::Engine.new 'XXX', sset

    eng.parse defn('A:',
                   '    _cache = true',
                   '    arg1 =?',
                   '    arg2 =?',
                   '    arg3 =?',
                   '    result = Dummy.all_of_me()',
                   'B:',
                   '    arg1 =?',
                   '    arg2 =?',
                   '    arg3 =?',
                   '    result = A(arg1=arg1, arg2=arg2, arg3=arg3).result',
                  )
    eng
  end

  after do
    default_callback = ::Delorean::Cache::NODE_CACHE_DEFAULT_CALLBACK

    ::Delorean::Cache.node_cache_callback = default_callback
    ::Delorean::Cache.adapter.clear_all!
  end

  def evaluate_b
    r = engine.evaluate('B', 'result', 'arg1' => 1, 'arg2' => 2, 'arg3' => 3)
    expect(r).to eq([{ 'name' => 'hello', 'foo' => 'bar' }])
  end

  def evaluate_a
    r = engine.evaluate('A', 'result', 'arg1' => 1, 'arg2' => 2, 'arg3' => 3)
    expect(r).to eq([{ 'name' => 'hello', 'foo' => 'bar' }])
  end

  it 'uses cache when the same arguments were passed' do
    expect(Dummy).to receive(:all_of_me).once.and_call_original
    2.times { evaluate_b }
  end

  it 'uses cache if evaluate is called from ruby' do
    expect(Dummy).to receive(:all_of_me).once.and_call_original
    2.times { evaluate_a }
  end

  it "doesn't use cache when the different arguments were passed" do
    expect(Dummy).to receive(:all_of_me).twice.and_call_original

    evaluate_a

    r = engine.evaluate('A', 'result', 'arg1' => 10, 'arg2' => 2, 'arg3' => 3)
    expect(r).to eq([{ 'name' => 'hello', 'foo' => 'bar' }])
  end

  describe 'compex caching' do
    let(:engine) do
      eng = Delorean::Engine.new 'XXX', sset

      eng.parse defn('A:',
                     '    _cache = true',
                     '    arg1 =?',
                     '    arg2 =?',
                     '    arg3 =?',
                     '    result = Dummy.all_of_me()',
                     'B:',
                     '    _cache = true',
                     '    arg1 =?',
                     '    arg2 =?',
                     '    arg3 =?',
                     '    result = [A(arg1=1, arg2=2, arg3=3).result, Dummy.one_or_two(1, 2)]',
                     'C:',
                     '    arg1 =?',
                     '    result = [ Dummy.call_me_maybe(2), B(arg1=arg1, arg2=2, arg3=3).result]',
                    )
      eng
    end

    it 'Calling node can be cached as well' do
      # A should be called once
      expect(Dummy).to receive(:all_of_me).once.and_call_original

      # B should be called twice
      expect(Dummy).to receive(:one_or_two).twice.and_call_original

      # C should be called 3 times
      expect(Dummy).to receive(:call_me_maybe).exactly(3).times
                                              .and_call_original

      2.times do
        r = engine.evaluate('C', 'result', 'arg1' => 1)
        expect(r).to eq([2, [[{ 'name' => 'hello', 'foo' => 'bar' }], [1, 2]]])
      end

      r = engine.evaluate('C', 'result', 'arg1' => 2)
      expect(r).to eq([2, [[{ 'name' => 'hello', 'foo' => 'bar' }], [1, 2]]])
    end
  end

  it 'allows to override caching callback 1' do
    ::Delorean::Cache.node_cache_callback = lambda do |**_kwargs|
      {
        cache: false,
      }
    end

    expect(Dummy).to receive(:all_of_me).twice.and_call_original
    2.times { evaluate_a }
  end

  it 'allows to override caching callback 2' do
    ::Delorean::Cache.node_cache_callback = lambda do |**_kwargs|
      {
        cache: true,
      }
    end

    expect(Dummy).to receive(:all_of_me).once.and_call_original
    2.times { evaluate_a }
  end
end
