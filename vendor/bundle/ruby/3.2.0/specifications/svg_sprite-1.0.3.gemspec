# -*- encoding: utf-8 -*-
# stub: svg_sprite 1.0.3 ruby lib

Gem::Specification.new do |s|
  s.name = "svg_sprite".freeze
  s.version = "1.0.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Nando Vieira".freeze]
  s.bindir = "exe".freeze
  s.date = "2023-01-17"
  s.description = "Create SVG sprites using SVG links.".freeze
  s.email = ["fnando.vieira@gmail.com".freeze]
  s.executables = ["svg_sprite".freeze]
  s.files = ["exe/svg_sprite".freeze]
  s.homepage = "https://github.com/fnando/svg_sprite".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Create SVG sprites using SVG links.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<nokogiri>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<svg_optimizer>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<thor>.freeze, [">= 0"])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
  s.add_development_dependency(%q<css_parser>.freeze, [">= 0"])
  s.add_development_dependency(%q<minitest>.freeze, [">= 0"])
  s.add_development_dependency(%q<minitest-utils>.freeze, [">= 0"])
  s.add_development_dependency(%q<pry-meta>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rubocop>.freeze, [">= 0"])
  s.add_development_dependency(%q<rubocop-fnando>.freeze, [">= 0"])
end
