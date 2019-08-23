require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'benchmark/ips'
require 'pry'

describe 'Delorean' do
  let(:sset) {
    TestContainer.new({
                      })
  }

  let(:engine) {
    Delorean::Engine.new "XXX", sset
  }

  it "hash splat performance as expected" do
    perf_test = <<-DELOREAN
    A:
        x = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        h = [[k, k.to_s] for k in x.product(x)].to_h
        hh = {**h, "a":1, "b":2, **h, **h, **h, "c":3}
    DELOREAN

    perf_test.gsub!(/^    /, '')

    engine.parse perf_test

    bm = Benchmark.ips do |x|
      x.report ('delorean') { engine.evaluate("A", "hh") }

      x.report('ruby') {
        x = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        h = x.product(x).map { |x| [x, x.to_s]}.to_h
        hh = h.merge("a"=>1, "b"=>2).merge(h).merge(h).merge(h).merge("c"=>3)
      }

      x.compare!
    end

    # get iterations/sec for each report
    h = bm.entries.each_with_object({}) {
      |e, h|
      h[e.label] = e.stats.central_tendency
    }

    factor = h['ruby']/h['delorean']

    p factor

    expect(factor).to be < 1.10
  end

  it "hash splat performance (2) as expected" do
    perf_test = <<-DELOREAN
    A:
        h =?
        hh = {**h, **h, **h, **h}
    DELOREAN

    perf_test.gsub!(/^    /, '')

    engine.parse perf_test

    x = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    h = x.product(x).map { |x| [x, x.to_s]}.to_h

    bm = Benchmark.ips do |x|
      x.report ('delorean') { engine.evaluate("A", "hh", {"h"=>h}) }

      x.report('ruby') {
        hh = h.merge(h).merge(h).merge(h)
      }

      x.report("ruby!") {
        hh = {}
        hh.merge!(h); hh.merge!(h); hh.merge!(h); hh.merge!(h);
      }

      x.compare!
    end

    # get iterations/sec for each report
    h = bm.entries.each_with_object({}) {
      |e, h|
      h[e.label] = e.stats.central_tendency
    }

    factor = h["ruby!"]/h['delorean']
    p factor
    expect(factor).to be_within(0.1).of(1.08)

    # perf of mutable vs immutable hash ops are as expected
    factor = h["ruby!"]/h['ruby']
    p factor
    expect(factor).to be_within(0.2).of(1.45)
  end

  it "hash literal performance as expected" do
    x=(1..10).to_a

    hdef1 = x.map { |i| "'#{'xo'*i}' : #{i}" }.join(',')
    hdef2 = x.map { |i| "'#{'yo'*i}' : #{i}" }.join(',')

    perf_test = <<-DELOREAN
    A:
        v =?
        h = { #{hdef1}, #{hdef2} }
    DELOREAN

    perf_test.gsub!(/^    /, '')

    puts perf_test

    engine.parse perf_test

    bm = Benchmark.ips do |x|
      x.report ('delorean') { engine.evaluate("A", "h", {}) }

      x.report('ruby') {
        h = {
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
      }

      x.compare!
    end

    # get iterations/sec for each report
    h = bm.entries.each_with_object({}) {
      |e, h|
      h[e.label] = e.stats.central_tendency
    }

    factor = h['ruby']/h['delorean']
    p factor
    expect(factor).to be_within(0.5).of(5.1)
  end

  it "array and node call performance as expected" do
    perf_test = <<-DELOREAN
    A:
        i =? 0
        max =?
        range = if i>max then [] else A(i=i+1, max=max).range + [i]

        res = [x*2 for x in range]
        result = res.sum
    DELOREAN

    perf_test.gsub!(/^    /, '')

    engine.parse perf_test

    bm = Benchmark.ips do |x|
      lim = 100

      x.report ('delorean') { engine.evaluate("A", "result", {"max"=>lim}) }

      x.report('ruby') {
        def range(max, i=0)
          i > max ? [] : range(max, i+1)
        end

        r = range(lim)
        result = r.map {|x| x*2}.sum
      }

      x.compare!
    end

    # get iterations/sec for each report
    h = bm.entries.each_with_object({}) {
      |e, h|
      h[e.label] = e.stats.central_tendency
    }

    factor = h['ruby']/h['delorean']

    p factor

    expect(factor).to be < 135
  end
end
