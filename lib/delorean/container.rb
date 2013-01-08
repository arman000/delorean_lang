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

    def get_by_name(name)
      k, engine = @engines.detect { |k, engine| k[0]==name }
      engine
    end

    def add(name, version, engine)
      @engines[ [name, version] ] = engine
    end

    def import(name, version)
      engine = get(name, version)

      return engine if engine

      if names.member? name
        n, v = @engines.keys.detect {|n, v| n == name}

        raise "Can't import #{name} version #{version}. " +
          "Collides with imported version #{v}."
      end

      add(name, version, get_engine(name, version))
    end

    def get_engine(name, version)
      raise "get_engine needs to be overriden"
    end
  end
end
