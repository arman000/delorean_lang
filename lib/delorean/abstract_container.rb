# frozen_string_literal: true

require 'delorean/base'

module Delorean
  class AbstractContainer
    def get_engine(_name)
      raise 'get_engine needs to be overriden'
    end
  end
end
