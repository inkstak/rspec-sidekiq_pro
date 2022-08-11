# frozen_string_literal: true

require "rspec/sidekiq_pro/matchers/job_matcher"

module RSpec
  module SidekiqPro
    module Matchers
      class EnqueueSidekiqJobs
        include JobMatcher

        def initialize(worker_class)
          @worker_class = worker_class
        end

        def supports_block_expectations?
          true
        end

        def supports_value_expectations?
          false
        end

        def matches?(block)
          super(capture_actual_jobs(block))
        end

        def does_not_match?(block)
          super(capture_actual_jobs(block))
        end

        def description
          "enqueue #{expected_job_description}"
        end

        def failure_message
          "expected to enqueue #{worker_class} job\n#{failure_message_diff}"
        end

        def failure_message_when_negated
          "expected not to enqueue #{worker_class} job\n#{failure_message_diff}"
        end

        def capture_actual_jobs(block)
          before = worker_class.jobs.dup
          result = block.call

          if @expected_arguments.is_a?(Proc)
            arguments = @expected_arguments.call(result)
            raise "arguments returned from a proc are expected to be an Array" unless arguments.is_a?(Array)

            @expected_arguments = normalize_arguments(arguments)
          end

          worker_class.jobs - before
        end
      end
    end
  end
end
