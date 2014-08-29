Gem::Specification.new do |gem|
  gem.authors       = ["Caleb Spare"]
  gem.email         = ["cespare@gmail.com"]
  gem.description   = %q{Simple parallel ssh.}
  gem.summary       = %q{Simple parallel ssh.}
  gem.homepage      = "https://github.com/cespare/weave"
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "weave"
  gem.require_paths = ["lib"]
  gem.version       = "1.1.0-beta1"

  gem.add_dependency "net-ssh", "~> 2.9"

  # For running integration tests.
  gem.add_development_dependency "minitest", "~> 5.0"
  gem.add_development_dependency "rake", "~> 10.0"
  # For generating the docs
  gem.add_development_dependency "yard", "~> 0.8"
  gem.add_development_dependency "redcarpet", "~> 3.0"
end
