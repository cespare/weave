# -*- encoding: utf-8 -*-
require File.expand_path('../lib/weave/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Caleb Spare"]
  gem.email         = ["cespare@gmail.com"]
  gem.description   = %q{Simple parallel ssh.}
  gem.summary       = %q{Simple parallel ssh.}
  gem.homepage      = "https://github.com/cespare/weave"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "weave"
  gem.require_paths = ["lib"]
  gem.version       = Weave::VERSION

  gem.add_dependency "net-ssh", ">= 2.2.0"

  # For running integration tests.
  gem.add_development_dependency "scope"
  gem.add_development_dependency "rake"
  # For generating the docs
  gem.add_development_dependency "yard"
  gem.add_development_dependency "redcarpet"
end
