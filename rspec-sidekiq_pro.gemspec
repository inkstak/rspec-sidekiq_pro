# frozen_string_literal: true

$:.push File.expand_path("lib", __dir__)
require "rspec/sidekiq_pro/version"

Gem::Specification.new do |s|
  s.name = "rspec-sidekiq_pro"
  s.version = RSpec::SidekiqPro::VERSION

  s.authors = ["Savater Sebastien"]
  s.email = "github.60k5k@simplelogin.co"

  s.homepage = "http://github.com/inkstak/rspec-sidekiq_pro"
  s.licenses = ["MIT"]
  s.summary = "A collection of tools and matchers for Sidekiq Pro"

  s.files = Dir["lib/**/*"] + %w[LICENSE README.md]
  s.require_paths = ["lib"]

  s.add_dependency "activesupport", ">= 6.0", "< 8"
  s.add_dependency "rspec", "~> 3.11"
  s.add_dependency "sidekiq", ">= 6.5", "< 8"
  s.add_dependency "sidekiq-pro", ">= 5.5", "< 8"
  s.add_dependency "zeitwerk", "~> 2.6"
end
