# frozen_string_literal: true

module RSpec
  module SidekiqPro
    module Matchers
      module JobMatcher
        include ::RSpec::Matchers::Composable

        attr_reader :worker_class,
          :expected_arguments,
          :expected_interval,
          :expected_timestamp,
          :expected_schedule,
          :expected_count,
          :expected_without_batch,
          :expected_batch,
          :actual_jobs

        def with(*expected_arguments, &block)
          if block
            raise ArgumentError, "setting block to `with` is not supported for this matcher" if supports_value_expectations?
            raise ArgumentError, "setting arguments and block together in `with` is not supported" if expected_arguments.any?
            @expected_arguments = block
          else
            @expected_arguments = normalize_arguments(expected_arguments)
          end

          self
        end

        def in(interval)
          raise "setting expecations with both `at` and `in` is not supported" if @expected_timestamp

          @expected_interval = interval
          @expected_schedule = interval.from_now.to_i
          self
        end

        def at(timestamp)
          raise "setting expecations with both `at` and `in` is not supported" if @expected_interval

          @expected_timestamp = timestamp
          @expected_schedule = timestamp.to_i
          self
        end

        def once
          exactly(1)
        end

        def twice
          exactly(2)
        end

        def exactly(times)
          @expected_count = times
          self
        end

        def times
          self
        end
        alias_method :time, :times

        def without_batch
          raise "setting expecations with both `without_batch` and `within_batch` is not supported" if @expected_batch

          @expected_without_batch = true
          self
        end

        def within_batch(batch_expectation = :__undef__, &block)
          raise "setting expecations with both `without_batch` and `within_batch` is not supported" if @expected_without_batch

          if block
            raise ArgumentError, "setting arguments and block together in `with_batch` is not supported" if batch_expectation != :__undef__

            @expected_batch = block
          else
            @expected_batch = batch_expectation
          end

          self
        end

        def matches?(jobs)
          @actual_jobs = jobs
          filtered_jobs = filter_jobs(actual_jobs)

          if expected_count
            filtered_jobs.count == expected_count
          else
            filtered_jobs.any?
          end
        end

        def does_not_match?(jobs)
          @actual_jobs = jobs
          filtered_jobs = filter_jobs(actual_jobs)

          if expected_count
            filtered_jobs.count != expected_count
          else
            filtered_jobs.empty?
          end
        end

        def normalize_arguments(arguments)
          JSON.parse(JSON.dump(arguments))
        end

        def output_arguments(arguments)
          arguments.map(&:inspect).join(", ")
        end

        def expected_job_description
          description = "#{worker_class} job"

          if expected_count == 1
            description += " once"
          elsif expected_count == 2
            description += " twice"
          elsif expected_count
            description += " #{expected_count} times"
          end

          if expected_arguments.is_a?(Proc)
            description += " with some arguments"
          elsif expected_arguments
            description += " with arguments #{expected_arguments}"
          end

          description
        end

        def failure_message_diff
          message = []
          message += expectations_in_failure_message
          message << "" if message.any?
          message << actual_jobs_size_in_failure_message

          if expected_arguments || expected_schedule || expected_without_batch || expected_batch
            message[-1] = "#{message[-1]}:"
            message += actual_jobs_details_in_failure_message
          end

          message.join("\n")
        end

        def actual_jobs_size_in_failure_message
          if actual_jobs.empty?
            "no #{worker_class} found"
          else
            "found #{actual_jobs.size} #{worker_class}"
          end
        end

        # rubocop:disable Layout/ExtraSpacing
        # It becomes unreadable when not allowing alignement
        def expectations_in_failure_message
          message = []
          message << "  exactly:   #{expected_count} time(s)"       if expected_count
          message << "  arguments: #{expected_arguments}"           if expected_arguments
          message << "  in:        #{expected_interval_output}"     if expected_interval
          message << "  at:        #{expected_timestamp}"           if expected_timestamp
          message << "  batch:     #{output_batch(expected_batch)}" if expected_batch
          message << "  batch:     no batch"                        if expected_without_batch
          message
        end

        def job_details_in_failure_message(job)
          message = []
          message << "  arguments: #{job["args"]}"                if expected_arguments
          message << "  at:        #{output_schedule(job["at"])}" if expected_schedule && job["at"]
          message << "  at:        no schedule"                   if expected_schedule && !job["at"]
          message << "  batch:     #{output_batch(job["bid"])}"   if (expected_without_batch || expected_batch) && job["bid"]
          message << "  batch:     no batch"                      if (expected_without_batch || expected_batch) && !job["bid"]
          message
        end

        def actual_jobs_details_in_failure_message
          actual_jobs.flat_map do |job|
            job_details_in_failure_message(job).map.with_index do |line, index|
              if actual_jobs.size > 1
                indent = "    "
                indent = "  - " if index.zero?
                line = "#{indent}#{line[2..]}"
              end

              line
            end
          end
        end

        # rubocop:enable Layout/ExtraSpacing

        def expected_interval_output
          "#{expected_interval.inspect} (#{output_schedule(expected_schedule)})"
        end

        def output_schedule(timestamp)
          Time.at(timestamp) if timestamp
        end

        def output_batch(value)
          case value
          when :__undef__
            "to be present"
          when String
            "<Sidekiq::Batch bid: #{value.inspect}>"
          when Sidekiq::Batch
            "<Sidekiq::Batch bid: #{value.bid.inspect}>"
          else
            if value.respond_to?(:description)
              value.description
            else
              value
            end
          end
        end

        def filter_jobs(jobs)
          jobs.select do |job|
            next if expected_arguments && !values_match?(expected_arguments, job["args"])
            next if expected_schedule && !values_match?(expected_schedule.to_i, job["at"].to_i)
            next if expected_without_batch && job["bid"]
            next if expected_batch && !batch_match?(expected_batch, job["bid"])

            true
          end
        end

        def batch_match?(expected_batch, bid)
          case expected_batch
          when :__undef__
            !bid.nil?
          when String
            expected_batch == bid
          when ::Sidekiq::Batch
            expected_batch.bid == bid
          else
            return unless bid

            batch = ::Sidekiq::Batch.new(bid)
            values_match?(expected_batch, batch)
          end
        end
      end
    end
  end
end
