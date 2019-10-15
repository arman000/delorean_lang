# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Delorean Ruby error handling' do
  after do
    ::Delorean::Ruby.error_handler = ::Delorean::Ruby::DEFAULT_ERROR_HANDLER
  end

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
    Delorean::Engine.new('XXX', sset).tap do |eng|
      eng.parse defn('A:',
                     '    b = ERR("test", 1, 2, 3)'
                    )
    end
  end

  it 'raises error' do
    expect { engine.evaluate('A', 'b') }.to raise_error(
      RuntimeError, 'test, 1, 2, 3'
    )
  end

  it 'allows to override handler' do
    ::Delorean::Ruby.error_handler = lambda do |*_args|
      raise StandardError, 'Overriden Error'
    end

    expect { engine.evaluate('A', 'b') }.to raise_error(
      StandardError, 'Overriden Error'
    )
  end
end
