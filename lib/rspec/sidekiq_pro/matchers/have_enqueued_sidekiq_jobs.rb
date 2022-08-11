# frozen_string_literal: true

require "rspec/sidekiq_pro/matchers/job_matcher"

module RSpec
  module SidekiqPro
    module Matchers
      class HaveEnqueuedSidekiqJobs
        include JobMatcher

        def supports_block_expectations?
          false
        end

        def supports_value_expectations?
          true
        end

        def matches?(worker_class)
          @worker_class = worker_class
          super(worker_class.jobs)
        end

        def does_not_match?(worker_class)
          @worker_class = worker_class
          super(worker_class.jobs)
        end

        def description
          "have enqueued #{expected_job_description}"
        end

        def failure_message
          "expected to have enqueued #{worker_class} job\n#{failure_message_diff}"
        end

        def failure_message_when_negated
          "expected not to have enqueued #{worker_class} job\n#{failure_message_diff}"
        end
      end
    end
  end
end
