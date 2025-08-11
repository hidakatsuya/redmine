# -*- encoding: utf-8 -*-
# stub: roadie 5.2.1 ruby lib

Gem::Specification.new do |s|
  s.name = "roadie".freeze
  s.version = "5.2.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Magnus Bergmark".freeze]
  s.date = "1980-01-01"
  s.description = "Roadie tries to make sending HTML emails a little less painful by inlining stylesheets and rewriting relative URLs for you.".freeze
  s.email = ["magnus.bergmark@gmail.com".freeze]
  s.extra_rdoc_files = ["README.md".freeze, "Changelog.md".freeze]
  s.files = ["Changelog.md".freeze, "README.md".freeze]
  s.homepage = "http://github.com/Mange/roadie".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Making HTML emails comfortable for the Ruby rockstars".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<nokogiri>.freeze, ["~> 1.15"])
  s.add_runtime_dependency(%q<css_parser>.freeze, ["~> 1.4"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
  s.add_development_dependency(%q<rspec-collection_matchers>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<webmock>.freeze, ["~> 3.0"])
  s.add_development_dependency(%q<standardrb>.freeze, [">= 0"])
end
