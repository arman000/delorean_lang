# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'benchmark/ips'
require 'pry'

describe 'Delorean' do
  let(:sset) do
    TestContainer.new({})
  end

  let(:engine) do
    Delorean::Engine.new 'XXX', sset
  end

  # FIXME: perhpas add more optimization to hash compilation
  xit 'hash splat performance as expected' do
    perf_test = <<-DELOREAN
    A:
        x = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        h = [[k, k.to_s] for k in x.product(x)].to_h
        hh = {**h, "a":1, "b":2, **h, **h, **h, "c":3}
    DELOREAN

    engine.parse perf_test.gsub(/^    /, '')

    bm = Benchmark.ips do |x|
      x.report('delorean') { engine.evaluate('A', 'hh') }

      x.report('ruby') do
        il = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        h = il.product(il).map { |i| [i, i.to_s] }.to_h
        h.merge('a' => 1, 'b' => 2).merge(h).merge(h).merge(h).merge('c' => 3)
      end

      x.compare!
    end

    # get iterations/sec for each report
    h = bm.entries.each_with_object({}) do |e, hh|
      hh[e.label] = e.stats.central_tendency
    end

    factor = h['ruby'] / h['delorean']

    # p factor

    expect(factor).to be < 1.10
  end

  it 'hash splat performance (2) as expected' do
    perf_test = <<-DELOREAN
    A:
        h =?
        hh = {**h, **h, **h, **h}
    DELOREAN

    engine.parse perf_test.gsub(/^    /, '')

    il = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    h = il.product(il).map { |i| [i, i.to_s] }.to_h

    bm = Benchmark.ips do |x|
      x.report('delorean') { engine.evaluate('A', 'hh', 'h' => h) }

      x.report('ruby') do
        h.merge(h).merge(h).merge(h)
      end

      x.report('ruby!') do
        hh = {}
        4.times { hh.merge!(h) }
      end

      x.compare!
    end

    # get iterations/sec for each report
    h = bm.entries.each_with_object({}) do |e, hh|
      hh[e.label] = e.stats.central_tendency
    end

    factor = h['ruby!'] / h['delorean']
    # p factor
    expect(factor).to be_within(0.25).of(0.9)

    # perf of mutable vs immutable hash ops are as expected
    factor = h['ruby!'] / h['ruby']
    # p factor
    expect(factor).to be_within(0.3).of(1.0)

    factor = h['ruby'] / h['delorean']
    # p factor
    expect(factor).to be_within(0.15).of(1.0)
  end

  it 'hash literal performance as expected' do
    il = (1..10).to_a

    hdef1 = il.map { |i| "'#{'xo' * i}' : #{i}" }.join(',')
    hdef2 = il.map { |i| "'#{'yo' * i}' : #{i}" }.join(',')

    perf_test = <<-DELOREAN
    A:
        v =?
        h = { #{hdef1}, #{hdef2} }
    DELOREAN

    engine.parse perf_test.gsub(/^    /, '')

    bm = Benchmark.ips do |x|
      x.report('delorean') { engine.evaluate('A', 'h', {}) }

      x.report('ruby') do
        {
          'xo' => 1,
          'xoxo' => 2,
          'xoxoxo' => 3,
          'xoxoxoxo' => 4,
          'xoxoxoxoxo' => 5,
          'xoxoxoxoxoxo' => 6,
          'xoxoxoxoxoxoxo' => 7,
          'xoxoxoxoxoxoxoxo' => 8,
          'xoxoxoxoxoxoxoxoxo' => 9,
          'xoxoxoxoxoxoxoxoxoxo' => 10,
          'yo' => 1,
          'yoyo' => 2,
          'yoyoyo' => 3,
          'yoyoyoyo' => 4,
          'yoyoyoyoyo' => 5,
          'yoyoyoyoyoyo' => 6,
          'yoyoyoyoyoyoyo' => 7,
          'yoyoyoyoyoyoyoyo' => 8,
          'yoyoyoyoyoyoyoyoyo' => 9,
          'yoyoyoyoyoyoyoyoyoyo' => 10,
        }
      end

      x.compare!
    end

    # get iterations/sec for each report
    h = bm.entries.each_with_object({}) do |e, hh|
      hh[e.label] = e.stats.central_tendency
    end

    factor = h['ruby'] / h['delorean']
    # p factor

    # FIXME: locally the factor is around 4, but in Gitlab CI it's around 7
    # expect(factor).to be_within(2.5).of(4)
    expect(factor).to be < 8
  end

  it 'cache allows to get result faster' do
    perf_test = <<-DELOREAN
    A:
        v =?
        result = Dummy.sleep_1ms

    AWithCache:
        _cache = true
        v =?
        result = Dummy.sleep_1ms
    DELOREAN

    engine.parse perf_test.gsub(/^    /, '')

    bm = Benchmark.ips do |x|
      x.report('delorean') do
        engine.evaluate('A', 'result', {})
      end

      x.report('delorean_node_cache') do
        engine.evaluate('AWithCache', 'result', {})
      end

      x.report('ruby') do
        Dummy.sleep_1ms
      end

      x.compare!
    end

    # get iterations/sec for each report
    h = bm.entries.each_with_object({}) do |e, hh|
      hh[e.label] = e.stats.central_tendency
    end

    cache_factor = h['delorean_node_cache'] / h['delorean']
    # p cache_factor

    expect(cache_factor).to be > 80
  end

  it 'array and node call performance as expected' do
    perf_test = <<-DELOREAN
    A:
        i =? 0
        max =?
        range = if i>max then [] else A(i=i+1, max=max).range + [i]

        res = [x*2 for x in range]
        result = res.sum
    DELOREAN

    engine.parse perf_test.gsub(/^    /, '')

    bm = Benchmark.ips do |x|
      lim = 100

      x.report('delorean') { engine.evaluate('A', 'result', 'max' => lim) }

      x.report('ruby') do
        def range(max, counter = 0)
          counter > max ? [] : range(max, counter + 1)
        end

        r = range(lim)
        r.map { |i| i * 2 }.sum
      end

      x.compare!
    end

    # get iterations/sec for each report
    h = bm.entries.each_with_object({}) do |e, hh|
      hh[e.label] = e.stats.central_tendency
    end

    factor = h['ruby'] / h['delorean']

    # p factor

    expect(factor).to be < 135
  end
end
