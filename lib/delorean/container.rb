require 'delorean/base'

module Delorean
  class AbstractContainer
    def initialize
      @engines = {}
    end

    def names
      @engines.keys.map {|n, v| n}
    end

    def get(name, version)
      @engines[ [name, version] ]
    end

    def add(name, version, engine)
      if names.member? name
        n, v = @engines.keys.detect {|n, v| n == name}

        raise "Can't import #{name} version #{version}. " +
          "Collides with imported version #{v}."
      end

      @engines[ [name, version] ] = engine
    end

    def add_imports(engine)
      # Given an engine, make sure that all of its imports are added
      # to the script container.  This makes sure we don't have
      # version conflict among different scripts.
      engine.imports.each { |name, ev|
        get(name, ev[1]) || add(name, ev[1], ev[0])
      }
    end

    def import(name, version)
      get(name, version) ||
        add(name, version, get_engine(name, version))
    end

    def get_engine(name, version)
      raise "get_engine needs to be overriden"
    end
  end
end
