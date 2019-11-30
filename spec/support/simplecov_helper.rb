# frozen_string_literal: true

# Credit to: https://gitlab.com/gitlab-org/gitlab-foss/blob/master/spec/simplecov_env.rb

require 'simplecov'

module SimpleCovHelper
  def self.configure_profile
    SimpleCov.configure do
      load_profile 'test_frameworks'
      load_profile 'root_filter'
      load_profile 'bundler_filter'
      track_files '{lib}/**/*.rb'

      add_filter 'lib/delorean/delorean.rb'
      add_filter '/vendor/ruby/'
      add_filter 'spec/'

      add_group 'Library', 'lib'
    end
  end

  def self.start!
    return unless ENV['COVERAGE'] == 'true'

    configure_profile

    SimpleCov.start
  end
end
