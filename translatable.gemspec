require_relative 'lib/translatable/version'

Gem::Specification.new do |s|
  s.name        = "json_translatable"
  s.version     = Translatable::VERSION
  s.authors     = ["Luka Bak"]
  s.email       = "bakluka@gmail.com"

  s.summary     = "I18n Rails gem that allows storing and querying translations for ActiveRecord models in a single JSON/JSONB column. "
  s.description = s.summary

  s.files       = Dir["lib/**/*"]
  s.require_paths = ["lib"]
  s.homepage    = "https://github.com/bakluka/json_translatable"
  s.license     = "MIT"

  s.required_ruby_version = ">= 2.7.0"

  s.add_dependency "activerecord", ">= 7.0"
  s.add_dependency "i18n", ">= 1.8"
end