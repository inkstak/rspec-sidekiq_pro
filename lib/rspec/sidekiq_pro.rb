# frozen_string_literal: true

require "rspec"
require "sidekiq"
require "sidekiq-pro"
require "sidekiq/testing"
require "active_support/duration"
require "rspec/sidekiq_pro/matchers"

# require "zeitwerk"

# loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
# loader.setup

# module RSpec
#   module SidekiqPro
#   end
# end

RSpec.configure do |config|
  config.include RSpec::SidekiqPro::Matchers
end
