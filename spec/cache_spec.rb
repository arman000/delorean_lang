require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Delorean cache" do
  before do
    Dummy.clear_lookup_cache!
  end

  it 'allows to set adapter' do
    ::Delorean::Cache.adapter = ::Delorean::Cache::Adapters::RubyCache.new(size_per_class: 100)
    expect(::Delorean::Cache.adapter.size_per_class).to eq 100
  end

  it 'uses cache' do
    expect(OpenStruct).to receive(:new).once.and_call_original

    res1 = Dummy.returns_cached_openstruct
    res2 = Dummy.returns_cached_openstruct

    expect(res1).to eq res2
  end

  it 'clears cache' do
    expect(OpenStruct).to receive(:new).twice.and_call_original
    Dummy.returns_cached_openstruct
    Dummy.clear_lookup_cache!
    Dummy.returns_cached_openstruct
  end

  it "doesn't use cache with infinity" do
    expect(OpenStruct).to receive(:new).twice.and_call_original

    res1 = Dummy.returns_cached_openstruct(Float::INFINITY)
    res2 = Dummy.returns_cached_openstruct(Float::INFINITY)

    expect(res1).to eq res2
  end

  it "doesn't use cache with different keys" do
    expect(OpenStruct).to receive(:new).twice.and_call_original

    Dummy.returns_cached_openstruct(1)
    Dummy.returns_cached_openstruct(2)
  end

  it 'removes outdated items from cache' do
    ::Delorean::Cache.adapter = ::Delorean::Cache::Adapters::RubyCache.new(size_per_class: 10)

    12.times do |t|
      Dummy.returns_cached_openstruct(t)
    end

    expect(::Delorean::Cache.adapter.fetch_item(klass: Dummy, cache_key: [:returns_cached_openstruct, 10])).to be_present
    expect(::Delorean::Cache.adapter.fetch_item(klass: Dummy, cache_key: [:returns_cached_openstruct, 2])).to_not be_present
  end
end
