Gem::Specification.new do |s|
  s.name        = 'lazy-json'
  s.version     = '1.0.0'
  s.date        = '2015-09-03'
  s.summary     = "lazy-json"
  s.description = "Lazy JSON skimmer-parser"
  s.authors     = ["Paul McReynolds"]
  s.email       = 'paul@conspire.com'
  s.files       = ["lib/lazy_json.rb"]
  s.homepage    = 'https://github.com/conspire-org/lazy-json'
  s.license     = 'MIT'
  s.add_runtime_dependency 'oj'
  s.add_development_dependency 'rspec'
end
