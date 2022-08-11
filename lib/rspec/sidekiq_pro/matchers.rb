# frozen_string_literal: true

require "rspec/sidekiq_pro/matchers/enqueue_sidekiq_jobs"
require "rspec/sidekiq_pro/matchers/have_enqueued_sidekiq_jobs"

module RSpec
  module SidekiqPro
    module Matchers
      # Checks if a certain job was enqueued.
      #
      # AwesomeWorker.perform_async
      # expect(AwesomeWorker).to have_enqueued_sidekiq_job
      #
      # AwesomeWorker.perform_async(42, 'David')
      # expect(AwesomeWorker).to have_enqueued_sidekiq_job.with(42, 'David')
      #
      # AwesomeWorker.perform_in(5.minutes)
      # expect(AwesomeWorker).to have_enqueued_sidekiq_job.in(5.minutes)
      #
      def have_enqueued_sidekiq_job
        HaveEnqueuedSidekiqJobs.new.once
      end

      def have_enqueued_sidekiq_jobs
        HaveEnqueuedSidekiqJobs.new
      end

      # Checks if a certain job was enqueued in a block.
      #
      # expect { AwesomeWorker.perform_async }
      #   .to enqueue_sidekiq_job(AwesomeWorker)
      #
      # expect { AwesomeWorker.perform_async(42, 'David')
      #   .to enqueue_sidekiq_job(AwesomeWorker).with(42, 'David')
      #
      # expect { AwesomeWorker.perform_in(5.minutes) }
      #   .to enqueue_sidekiq_job(AwesomeWorker).in(5.minutes)
      #
      def enqueue_sidekiq_job(worker_class)
        EnqueueSidekiqJobs.new(worker_class).once
      end

      def enqueue_sidekiq_jobs(worker_class)
        EnqueueSidekiqJobs.new(worker_class)
      end
    end
  end
end
