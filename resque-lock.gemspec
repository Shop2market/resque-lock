lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'resque'
require 'resque/lock/version'


Gem::Specification.new do |s|
  s.name        = "resque-lock"
  s.version     = Resque::Lock::VERSION
  s.authors     = ["Shop2Market"]
  s.email       = "dev@shop2market.com"
  s.homepage    = "http://www.shop2market.com"
  s.summary     = "Locking lib"
  s.description = "Locking lib"
  s.licenses     = 'NTP'

  s.files        = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'resque'
  s.add_runtime_dependency 'resque-status'
  s.add_runtime_dependency 'uuid'

  s.add_development_dependency "bundler", "~> 1.5"
  s.add_development_dependency "rake"
  s.add_development_dependency "mocha"
  s.add_development_dependency "minitest"
end
