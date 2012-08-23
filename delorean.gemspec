require File.expand_path('../lib/delorean/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Arman Bostani"]
  gem.email         = ["abostani@pnmac.com"]
  gem.description   = %q{A "compiler" for the Delorean programming language}
  gem.summary       = %q{Delorean compiler}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "delorean"
  gem.require_paths = ["lib"]
  gem.version       = Delorean::VERSION

  gem.add_dependency "treetop"
  gem.add_dependency "activerecord"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "sqlite3"
end
