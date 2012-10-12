# -*- encoding: utf-8 -*-
require File.expand_path('../lib/gossamer/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Caleb Spare"]
  gem.email         = ["cespare@gmail.com"]
  gem.description   = %q{Simple parallel ssh.}
  gem.summary       = %q{Simple parallel ssh.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "gossamer"
  gem.require_paths = ["lib"]
  gem.version       = Gossamer::VERSION

  # For running integration tests.
  gem.add_development_dependency "vagrant"
  gem.add_development_dependency "scope"
  gem.add_development_dependency "rake"
end
