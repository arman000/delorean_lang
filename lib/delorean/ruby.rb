# frozen_string_literal: true

require 'delorean/ruby/whitelists'

module Delorean
  module Ruby
    DEFAULT_ERROR_HANDLER = lambda do |*args|
      str = args.map(&:to_s).join(', ')
      raise str
    end

    def self.whitelist=(new_whitelist)
      @whitelist = new_whitelist
    end

    def self.whitelist
      @whitelist
    end

    def self.error_handler=(new_handler)
      @error_handler = new_handler
    end

    def self.error_handler
      @error_handler
    end
  end
end
