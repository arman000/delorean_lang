require 'delorean/ruby/whitelists'

module Delorean
  module Ruby
    def self.whitelist=(new_whitelist)
      @whitelist = new_whitelist
    end

    def self.whitelist
      @whitelist
    end
  end
end
