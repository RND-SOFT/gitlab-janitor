lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

# Maintain your gem's version:
require 'gitlab-janitor/version'

Gem::Specification.new 'gitlab-janitor' do |spec|
  spec.version       = ENV['BUILDVERSION'].to_i > 0 ? "#{Lusnoc::VERSION}.#{ENV['BUILDVERSION'].to_i}" : GitlabJanitor::VERSION
  spec.authors       = ['Samoilenko Yuri']
  spec.email         = ['kinnalru@gmail.com']
  spec.description   = spec.summary = 'GitLab Janitor is a tool to automatically manage stalled containers when using Docker.'
  spec.homepage      = 'https://github.com/RnD-Soft/gitlab-janitor'
  spec.license       = 'MIT'

  spec.files         = Dir['bin/**/*', 'lib/**/*', 'Gemfile*', 'LICENSE', 'README.md', 'Dockerfile*', 'docker-compose.yml', '*.gemspec']
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/gitlab-janitor}) {|f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.0', '>= 2.0.1'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-console'
  spec.add_development_dependency 'awesome_print'

  spec.add_runtime_dependency 'tzinfo-data'
  spec.add_runtime_dependency 'activesupport', '~> 6.0'
  spec.add_runtime_dependency 'docker-api'
  spec.add_runtime_dependency 'fugit'
  spec.add_runtime_dependency 'optparse'
end

