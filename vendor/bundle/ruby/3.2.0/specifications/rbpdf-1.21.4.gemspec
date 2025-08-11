# -*- encoding: utf-8 -*-
# stub: rbpdf 1.21.4 ruby lib

Gem::Specification.new do |s|
  s.name = "rbpdf".freeze
  s.version = "1.21.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["NAITOH Jun".freeze]
  s.date = "2025-05-06"
  s.description = "A template plugin allowing the inclusion of ERB-enabled RBPDF template files.".freeze
  s.email = ["naitoh@gmail.com".freeze]
  s.homepage = "".freeze
  s.licenses = ["MIT".freeze, "LGPL-2.1-or-later".freeze]
  s.rdoc_options = ["--exclude".freeze, "lib/core/mini_magick.rb".freeze, "--exclude".freeze, "lib/htmlcolors.rb".freeze, "--exclude".freeze, "lib/unicode_data.rb".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.3.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "RBPDF via TCPDF.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<htmlentities>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<rbpdf-font>.freeze, ["~> 1.19.0"])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<test-unit>.freeze, [">= 0"])
  s.add_development_dependency(%q<webrick>.freeze, [">= 0"])
end
