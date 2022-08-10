# frozen_string_literal: true

$:.push File.expand_path("lib", __dir__)
require "rspec-sidekiq_pro/version"

Gem::Specification.new do |s|
  s.name     = "rspec-sidekiq_pro"
  s.version  = Rspec::SidekiqPro::VERSION

  s.authors = ["Savater Sebastien"]
  s.email   = "github.60k5k@simplelogin.co"

  s.homepage = "http://github.com/inkstak/rspec-sidekiq_pro"
  s.licenses = ["MIT"]
  s.summary  = "A collection of tools and matchers for Sidekiq Pro"

  s.files         = Dir["lib/**/*"] + %w[LICENSE README.md]
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler"
  s.add_development_dependency "gem-release"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "rubocop"
  s.add_development_dependency "rubocop-rake"
  s.add_development_dependency "rubocop-rspec"
  s.add_development_dependency "rubocop-performance"
  s.add_development_dependency "standard"
  s.add_development_dependency "zeitwerk"
end
