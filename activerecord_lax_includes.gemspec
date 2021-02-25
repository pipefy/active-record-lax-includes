# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'activerecord_lax_includes'
  s.version     = '0.2.4'
  s.summary     = 'Hotfix nested eager loading for polymorphic and STI relation in ActiveRecord'
  s.author      = ['Gabriel Custódio']
  s.email       = ['gabriel.custodio@pipefy.com']
  s.homepage    = 'http://github.com/pipefy/active-record-lax-includes'

  s.files = Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  s.require_path = 'lib'

  s.add_runtime_dependency 'rails', '>= 4.2', '< 6.0'

  s.add_development_dependency 'pry'
  s.add_development_dependency 'pry-byebug'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'rubocop-performance'
  s.add_development_dependency 'rubocop-rspec'
  s.add_development_dependency 'simplecov'
end
