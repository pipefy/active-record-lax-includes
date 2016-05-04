Gem::Specification.new do |s|
  s.name        = 'activerecord_lax_includes_2'
  s.version     = '0.2.0'
  s.summary     = 'Hotfix nested eager loading for polymorphic and STI relation in ActiveRecord'
  s.author      = 'Charles Barbier'
  s.email       = 'unixcharles@gmail.com'
  s.homepage    = 'http://github.com/unixcharles/active-record-lax-includes'

  s.files        = Dir['README.md', 'LICENSE', 'lib/activerecord_lax_includes.rb']
  s.require_path = 'lib'
end
