# frozen_string_literal: true

require "rspec"
require "sidekiq"
require "sidekiq-pro"
require "sidekiq/testing"
require "active_support/duration"
require "active_support/core_ext/module/delegation"
require "rspec/sidekiq_pro/matchers"
require "rspec/sidekiq_pro/batches"

RSpec.configure do |config|
  config.include RSpec::SidekiqPro::Matchers
end
