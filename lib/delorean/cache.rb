require 'delorean/cache/adapters'

module Delorean
  module Cache
    def self.adapter
      @adapter
    end

    def self.adapter=(new_adapter)
      @adapter = new_adapter
    end
  end
end
