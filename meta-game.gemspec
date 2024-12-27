Gem::Specification.new do |spec|
  spec.name          = 'meta-game'
  spec.version       = '0.1.0'
  spec.authors       = ['Aylon-Arlon']
  spec.email         = ['midscore.io@gmail.com']

  spec.summary       = 'A short summary of the Meta Game project'
  spec.description   = 'A longer description of the Meta Game project'
  spec.homepage      = 'http://github.com/ZeroPivot'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*.rb']
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'puma'
  spec.add_runtime_dependency 'oj'
  spec.add_runtime_dependency 'rack', '~> 3.0'
  spec.add_runtime_dependency 'rake'
  spec.add_runtime_dependency 'redis'
  spec.add_runtime_dependency 'bcrypt'
end
