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
          diff = []

          # rubocop:disable Layout/ExtraSpacing
          # It becomes unreadable when not allowing alignement
          diff << "  exactly:   #{expected_count} time(s)"       if expected_count
          diff << "  arguments: #{expected_arguments}"           if expected_arguments
          diff << "  in:        #{expected_interval_output}"     if expected_interval
          diff << "  at:        #{expected_timestamp}"           if expected_timestamp
          diff << "  batch:     #{output_batch(expected_batch)}" if expected_batch
          diff << "  batch:     no batch"                        if expected_without_batch
          diff << "" if diff.any?
          # rubocop:enable Layout/ExtraSpacing

          if actual_jobs.empty?
            diff << "no #{worker_class} found"
          elsif !expected_arguments && !expected_schedule && !expected_without_batch && !expected_batch
            diff << "found #{actual_jobs.size} #{worker_class}"
          else
            diff << "found #{actual_jobs.size} #{worker_class}:"

            actual_jobs.each do |job|
              job_message = []

              # rubocop:disable Layout/ExtraSpacing
              # It becomes unreadable when not allowing alignement
              job_message << "arguments: #{job["args"]}"                if expected_arguments
              job_message << "at:        #{output_schedule(job["at"])}" if expected_schedule && job["at"]
              job_message << "at:        no schedule"                   if expected_schedule && !job["at"]
              job_message << "batch:     #{output_batch(job["bid"])}"   if (expected_without_batch || expected_batch) && job["bid"]
              job_message << "batch:     no batch"                      if (expected_without_batch || expected_batch) && !job["bid"]
              # rubocop:enable Layout/ExtraSpacing

              diff += job_message.map.with_index do |line, index|
                if actual_jobs.size == 1
                  "  #{line}"
                elsif index.zero?
                  "  - #{line}"
                else
                  "    #{line}"
                end
              end
            end
          end

          diff.join("\n")
        end

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
