# frozen_string_literal: true

require "bundler/setup"
Bundler.setup

require "active_support/core_ext/numeric/time"
require "active_support"
require "rspec/sidekiq_pro"
require "super_diff/rspec" if ENV["SUPER_DIFF"]
require "timecop"
require "simplecov"
require "simplecov_json_formatter"
SimpleCov.start

RSpec.configure do |config|
  config.expect_with :rspec do |expect|
    expect.syntax = :expect
    expect.max_formatted_output_length = 1024
  end

  config.before do
    Sidekiq::Queues.clear_all
    RSpec::SidekiqPro::Batches.clear_all
  end

  config.after do
    Sidekiq::Queues.clear_all
    RSpec::SidekiqPro::Batches.clear_all
    Timecop.return
  end
end
