# frozen_string_literal: true

require_relative '../spec_helper'
require 'delorean/ruby/whitelists/empty'

describe 'Delorean Ruby whitelisting' do
  it 'allows to override whitelist with an empty one' do
    old_whitelist = ::Delorean::Ruby.whitelist
    ::Delorean::Ruby.whitelist = whitelist
    expect(whitelist.matchers).to be_empty

    ::Delorean::Ruby.whitelist = ::Delorean::Ruby::Whitelists::Default.new
    expect(::Delorean::Ruby.whitelist.matchers).to_not be_empty

    ::Delorean::Ruby.whitelist = old_whitelist
  end

  let(:whitelist) { ::Delorean::Ruby::Whitelists::Empty.new }

  describe 'methods' do
    before do
      whitelist.add_method :testmethod do |method|
        method.called_on Dummy
      end

      whitelist.add_method :testmethod_with_args do |method|
        method.called_on Dummy, with: [Numeric, [String, nil], [String, nil]]
      end
    end

    let(:matcher) { whitelist.matcher(method_name: :testmethod) }
    let(:matcher_with_args) do
      whitelist.matcher(method_name: :testmethod_with_args)
    end

    it 'matches method' do
      matcher = whitelist.matcher(method_name: :testmethod)
      expect(matcher).to_not be_nil
      expect { matcher.match!(klass: Dummy, args: []) }.to_not raise_error
    end

    it 'allows missing nillable arguments' do
      expect do
        matcher_with_args.match!(klass: Dummy, args: [1])
      end.to_not raise_error
    end

    it 'raises error if method not allowed for a class' do
      expect do
        matcher.match!(klass: Date, args: [])
      end.to raise_error('no such method testmethod for Date')
    end

    it 'raises error if arguments list is too long' do
      expect do
        matcher.match!(klass: Dummy, args: [1])
      end.to raise_error('too many args to testmethod')
    end

    it 'raises error if arguments list is too short' do
      expect do
        matcher_with_args.match!(klass: Dummy, args: [])
      end.to raise_error(
        'bad arg 0, method testmethod_with_args: /NilClass [Numeric]'
      )
    end

    it 'raises error if argument type is wrong' do
      expect do
        matcher_with_args.match!(klass: Dummy, args: [1, 2])
      end.to raise_error(
        "bad arg 1, method testmethod_with_args: 2/#{2.class} [String, nil]"
      )
    end

    it 'allows match one method to another' do
      whitelist.add_method :testmethod_matched, match_to: :testmethod_with_args
      matcher = whitelist.matcher(method_name: :testmethod_matched)
      expect(matcher.match_to?).to be true
    end
  end

  describe 'class_methods' do
    let(:method_matcher) do
      Delorean::Ruby.whitelist.class_method_matcher(method_name: :test_method)
    end

    let(:engine) do
      engine = Delorean::Engine.new 'XXX'

      engine.parse defn(
        'A:',
        '    a = RootClass.test_method(1)',
        '    b = RootClass.test_method(true)',
        '    c = RootClassChild.test_method("test")',
        '    d = RootClassChild.test_method(1)',
        '    e = RootClassChildsChild.test_method(true)',
        '    f = RootClassChildsChild.test_method(1)',
        '    g = RootClassChildsChildsChild.test_method(true)',
        '    h = RootClassChildsChildsChild.test_method(1)',
        '    i = RootClassChildsChildsChild.test_method()',
        '    j = RootClassChildsChildsChild.test_method',
        '    k = RootClassChildsChildsChild.test_method(true, true)',
        '    l = RootClassChildsChildsChild.test_method2(true)',
        '    m = RootClassChildsChildsChild.test_private_method',
      )

      engine
    end

    it 'fetches the closest method matcher in class hierarchy' do
      arg_matcher = method_matcher.matcher(klass: RootClass)
      expect(arg_matcher.with).to eq [Integer]

      arg_matcher = method_matcher.matcher(klass: RootClassChild)
      expect(arg_matcher.with).to eq [String]

      arg_matcher = method_matcher.matcher(klass: RootClassChildsChild)
      expect(arg_matcher.with).to eq [TrueClass]

      arg_matcher = method_matcher.matcher(klass: RootClassChildsChildsChild)
      expect(arg_matcher.with).to eq [TrueClass]
    end

    it 'allows to call methods correctly' do
      r = engine.evaluate('A', 'a')
      expect(r).to eq :test_method_with_int_arg

      r = engine.evaluate('A', 'c')
      expect(r).to eq :test_method_with_str_arg

      r = engine.evaluate('A', 'e')
      expect(r).to eq :test_method_with_true_arg

      r = engine.evaluate('A', 'g')
      expect(r).to eq :test_method_with_true_arg
    end

    it 'raises exception if argument type mismatched' do
      expect { engine.evaluate('A', 'b') }.to raise_error(
        RuntimeError,
        'bad arg 0, method test_method: true/TrueClass [Integer]'
      )

      expect { engine.evaluate('A', 'd') }.to raise_error(
        RuntimeError,
        'bad arg 0, method test_method: 1/Integer [String]'
      )

      expect { engine.evaluate('A', 'f') }.to raise_error(
        RuntimeError,
        'bad arg 0, method test_method: 1/Integer [TrueClass]'
      )

      expect { engine.evaluate('A', 'h') }.to raise_error(
        RuntimeError,
        'bad arg 0, method test_method: 1/Integer [TrueClass]'
      )
    end

    it 'raises exception if argument is not present' do
      expect { engine.evaluate('A', 'i') }.to raise_error(
        RuntimeError,
        'bad arg 0, method test_method: /NilClass [TrueClass]'
      )

      expect { engine.evaluate('A', 'j') }.to raise_error(
        Delorean::InvalidGetAttribute,
        "attr lookup failed: 'test_method' on <Class> RootClassChildsChildsChild - bad arg 0, method test_method: /NilClass [TrueClass]"
      )
    end

    it 'raises exception if too many arguments' do
      expect { engine.evaluate('A', 'k') }.to raise_error(
        RuntimeError,
        'too many args to test_method'
      )
    end

    it 'raises exception method is not whitelisted' do
      expect { engine.evaluate('A', 'l') }.to raise_error(
        RuntimeError,
        'no such method test_method2'
      )
    end

    it 'raises exception method is private' do
      expect { engine.evaluate('A', 'm') }.to raise_error(
        Delorean::InvalidGetAttribute,
        /private method `test_private_method/
      )
    end
  end
end
