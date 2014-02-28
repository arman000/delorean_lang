require 'delorean/base'

class Delorean::AbstractContainer
  def initialize
    @engines = {}
  end

  def get(name)
    @engines[name]
  end

  def add(name, engine)
    @engines[name] = engine
  end

  def add_imports(engine)
    engine.imports.each { |name, engine|
      get(name) || add(name, engine)
    }
  end

  def import(name)
    get(name) || add(name, get_engine(name))
  end

  def get_engine(name)
    raise "get_engine needs to be overriden"
  end
end
