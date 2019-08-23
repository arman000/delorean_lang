# frozen_string_literal: true

require 'delorean/ruby/whitelists/base'

module Delorean
  module Ruby
    module Whitelists
      class Empty < ::Delorean::Ruby::Whitelists::Base
        def initialize_hook; end
      end
    end
  end
end
