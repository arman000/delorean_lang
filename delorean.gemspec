# frozen_string_literal: true

require File.expand_path('lib/delorean/version', __dir__)

Gem::Specification.new do |gem|
  gem.authors       = ['Arman Bostani']
  gem.email         = ['arman.bostani@pnmac.com']
  gem.description   = 'A "compiler" for the Delorean programming language'
  gem.summary       = 'Delorean compiler'
  gem.homepage      = 'https://github.com/arman000/delorean_lang'

  gem.files         = `git ls-files`.split($OUTPUT_RECORD_SEPARATOR)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = 'delorean_lang'
  gem.require_paths = ['lib']
  gem.version       = Delorean::VERSION
  gem.licenses      = ['MIT']

  gem.add_dependency 'activerecord', '>= 3.2'
  gem.add_dependency 'treetop', '~> 1.5'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'rspec', '~> 2.1'
  gem.add_development_dependency 'rubocop'
  gem.add_development_dependency 'sqlite3', '~> 1.3.10'
end
