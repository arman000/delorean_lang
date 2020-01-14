# frozen_string_literal: true

require File.expand_path('lib/delorean/version', __dir__)

git_tracked_files = `git ls-files`.split($OUTPUT_RECORD_SEPARATOR)
gem_ignored_files = `git ls-files -i -X .gemignore`.split(
  $OUTPUT_RECORD_SEPARATOR
)
files = git_tracked_files - gem_ignored_files

Gem::Specification.new do |gem|
  gem.authors       = ['Arman Bostani']
  gem.email         = ['arman.bostani@pnmac.com']
  gem.description   = 'A "compiler" for the Delorean programming language'
  gem.summary       = 'Delorean compiler'
  gem.homepage      = 'https://github.com/arman000/delorean_lang'

  gem.files         = files
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = 'delorean_lang'
  gem.require_paths = ['lib']
  gem.version       = Delorean::VERSION
  gem.licenses      = ['MIT']

  gem.add_dependency 'activerecord'
  gem.add_dependency 'treetop'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rspec-instafail'
  gem.add_development_dependency 'rubocop'
  gem.add_development_dependency 'rubocop-performance'
  gem.add_development_dependency 'sqlite3'
end
