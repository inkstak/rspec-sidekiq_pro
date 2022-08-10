# frozen_string_literal: true

require "bundler/setup"
Bundler.setup

require "rspec-sidekiq_pro"

RSpec.configure do |config|
  config.order = "random"
  config.expect_with :rspec do |expect|
    expect.syntax = :expect
  end
end
