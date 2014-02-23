$:.push File.expand_path("../lib", __FILE__)
require "telemetry/version"

Gem::Specification.new do |s|
  s.name = 'telemetry-tracer'
  s.version = Telemetry::VERSION
  s.date = '2014-02-17'
  s.summary = ""
  s.description = ""
  s.authors = ["Ryan Kennedy", "Anjali Shenoy"]
  s.email = ["rkennedy@yammer-inc.com", "ashenoy@yammer-inc.com"]
  s.homepage = 'https://github.com/yammer/telemetry-tracer'
  s.license = 'Apache 2.0'

  s.files = `git ls-files`.split("\n")
  s.add_dependency('celluloid', '~>0.15')
  s.require_paths = ["lib"]
end
