# -*- encoding: utf-8 -*-
# stub: rbpdf-font 1.19.1 ruby lib

Gem::Specification.new do |s|
  s.name = "rbpdf-font".freeze
  s.version = "1.19.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["NAITOH Jun".freeze]
  s.date = "2017-03-29"
  s.description = "RBPDF font files.".freeze
  s.email = ["naitoh@gmail.com".freeze]
  s.homepage = "".freeze
  s.rdoc_options = ["--exclude".freeze, "lib/fonts/".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "RBPDF Font.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<bundler>.freeze, ["~> 1.6"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<test-unit>.freeze, ["~> 3.2"])
end
