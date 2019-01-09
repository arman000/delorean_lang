require 'delorean/base'

module Delorean
  class AbstractContainer
    def get_engine(name)
      raise "get_engine needs to be overriden"
    end
  end
end
