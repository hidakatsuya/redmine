# -*- encoding: utf-8 -*-
# stub: svg_optimizer 0.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "svg_optimizer".freeze
  s.version = "0.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Nando Vieira".freeze]
  s.date = "2023-09-25"
  s.description = "SVG optimization based on Node's SVGO".freeze
  s.email = ["fnando.vieira@gmail.com".freeze]
  s.homepage = "https://github.com/fnando/svg_optimizer".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "SVG optimization based on Node's SVGO".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<nokogiri>.freeze, [">= 0"])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
  s.add_development_dependency(%q<minitest-utils>.freeze, [">= 0"])
  s.add_development_dependency(%q<pry-meta>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rubocop>.freeze, [">= 0"])
  s.add_development_dependency(%q<rubocop-fnando>.freeze, [">= 0"])
  s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
end
