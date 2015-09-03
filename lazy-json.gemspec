Gem::Specification.new do |s|
  s.name        = 'lazy-json'
  s.version     = '1.0.0'
  s.date        = '2015-09-03'
  s.summary     = "Lazy JSON"
  s.description = "Lazy JSON skimmer-parser"
  s.authors     = ["Paul McReynolds"]
  s.email       = 'paul@conspire.com'
  s.files       = ["lib/lazy-json.rb"]
  s.homepage    = 'https://github.com/conspire-org/lazy-json'
  s.license     = 'MIT'
  s.add_runtime_dependency 'oj', '~>2'
  s.add_development_dependency 'rspec', '~>3'
end
