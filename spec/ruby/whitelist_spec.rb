require_relative '../spec_helper'
require 'delorean/ruby/whitelists/empty'

describe "Delorean Ruby whitelisting" do
  it 'allows to override whitelist with an empty one' do
    ::Delorean::Ruby.whitelist = whitelist
    expect(whitelist.matchers).to be_empty

    ::Delorean::Ruby.whitelist = ::Delorean::Ruby::Whitelists::Default.new
    expect(::Delorean::Ruby.whitelist.matchers).to_not be_empty
  end

  let(:whitelist) { ::Delorean::Ruby::Whitelists::Empty.new }

  describe "methods" do
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
      expect do matcher.match!(klass: Dummy, args: [1])
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
end
