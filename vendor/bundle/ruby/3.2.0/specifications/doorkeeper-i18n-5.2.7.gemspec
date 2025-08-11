# -*- encoding: utf-8 -*-
# stub: doorkeeper-i18n 5.2.7 ruby lib

Gem::Specification.new do |s|
  s.name = "doorkeeper-i18n".freeze
  s.version = "5.2.7"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/doorkeeper-gem/doorkeeper-i18n/issues", "homepage_uri" => "https://github.com/doorkeeper-gem/doorkeeper-i18n", "source_code_uri" => "https://github.com/doorkeeper-gem/doorkeeper-i18n" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Tute Costa".freeze, "Nikita Bulai".freeze]
  s.date = "2023-09-27"
  s.description = "Translations for doorkeeper rubygem.".freeze
  s.email = ["bulaj.nikita@gmail.com".freeze]
  s.homepage = "https://github.com/doorkeeper-gem/doorkeeper-i18n".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Translations for doorkeeper rubygem.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<doorkeeper>.freeze, [">= 5.2"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
  s.add_development_dependency(%q<i18n-spec>.freeze, ["~> 0.6.0"])
  s.add_development_dependency(%q<railties>.freeze, [">= 0"])
end
