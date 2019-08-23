# frozen_string_literal: true

require 'delorean/const'
require 'delorean/functions'

module Delorean
  module Model
    def self.included(base)
      base.send :extend, ::Delorean::Functions
    end
  end
end
