# frozen_string_literal: true

require "spec_helper"

RSpec.describe RSpec::SidekiqPro::Matchers::EnqueueSidekiqJobs do
  let(:sample_job_class) do
    Class.new do
      include Sidekiq::Job

      def perform(*args)
        # Do nothing
      end
    end
  end

  before do
    stub_const("SampleJob",  Class.new(sample_job_class))
    stub_const("SampleJob2", Class.new(sample_job_class))

    Timecop.freeze("2022-08-10 00:00:00")
  end

  def create_worker_and_return_arguments
    SampleJob.perform_async(1, 2, 3)
    [1, 2, 3]
  end

  it "asserts that a job will be enqueued" do
    expect {
      SampleJob.perform_async
      SampleJob.perform_async
    }.to enqueue_sidekiq_jobs(SampleJob)
  end

  it "asserts that only one job will be enqueued" do
    expect {
      SampleJob.perform_async
    }.to enqueue_sidekiq_job(SampleJob)
  end

  it "fails assertion when no jobs match" do
    expect {
      expect {
        SampleJob2.perform_async
        SampleJob2.perform_async
      }.to enqueue_sidekiq_jobs(SampleJob)
    }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
      expected to enqueue SampleJob job
      no SampleJob found
    MESSAGE
  end

  it "fails assertion when not only one job matches" do
    expect {
      expect {
        SampleJob.perform_async
        SampleJob.perform_async
      }.to enqueue_sidekiq_job(SampleJob)
    }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
      expected to enqueue SampleJob job
        exactly:   1 time(s)

      found 2 SampleJob
    MESSAGE
  end

  describe "negative matcher" do
    it "asserts that no jobs has been enqueued" do
      expect {
        SampleJob2.perform_async
        SampleJob2.perform_async
      }.not_to enqueue_sidekiq_jobs(SampleJob)
    end

    it "asserts that not only one job has been enqueued" do
      expect {
        SampleJob2.perform_async
        SampleJob2.perform_async
      }.not_to enqueue_sidekiq_job(SampleJob)
    end

    it "fails assertion when some jobs match" do
      expect {
        expect {
          SampleJob.perform_async
          SampleJob.perform_async
        }.not_to enqueue_sidekiq_jobs(SampleJob)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected not to enqueue SampleJob job
        found 2 SampleJob
      MESSAGE
    end
  end

  describe "arguments matching" do
    it "asserts that arguments match" do
      expect {
        SampleJob.perform_async(1, 2, 3)
      }.to enqueue_sidekiq_jobs(SampleJob).with(1, 2, 3)
    end

    it "assets that even not-normalized arguments match" do
      expect {
        SampleJob.perform_async("foo")
      }.to enqueue_sidekiq_jobs(SampleJob).with(:foo)
    end

    it "asserts that arguments match against multiple jobs" do
      expect {
        SampleJob.perform_async(1)
        SampleJob.perform_async(2)
        SampleJob.perform_async(3)
      }.to enqueue_sidekiq_jobs(SampleJob).with(3)
    end

    it "fails assertion when the enqueued job doesn't match expected arguments" do
      expect {
        expect {
          SampleJob.perform_async(1, 2, 3)
        }.to enqueue_sidekiq_jobs(SampleJob).with(1)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to enqueue SampleJob job
          arguments: [1]

        found 1 SampleJob:
          arguments: [1, 2, 3]
      MESSAGE
    end

    it "fails assertion when none of the enqueued jobs match expected arguments" do
      expect {
        expect {
          SampleJob.perform_async(1)
          SampleJob.perform_async(2)
          SampleJob.perform_async(3)
        }.to enqueue_sidekiq_jobs(SampleJob).with(4)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to enqueue SampleJob job
          arguments: [4]

        found 3 SampleJob:
          - arguments: [1]
          - arguments: [2]
          - arguments: [3]
      MESSAGE
    end

    describe "negative matcher" do
      it "asserts that no jobs match the expected arguments" do
        expect {
          SampleJob.perform_async(1)
          SampleJob.perform_async(2)
          SampleJob.perform_async(3)
        }.not_to enqueue_sidekiq_jobs(SampleJob).with(4)
      end

      it "fails when some arguments match" do
        expect {
          expect {
            SampleJob.perform_async(1)
            SampleJob.perform_async(2)
            SampleJob.perform_async(3)
          }.not_to enqueue_sidekiq_jobs(SampleJob).with(3)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
          expected not to enqueue SampleJob job
            arguments: [3]

          found 3 SampleJob:
            - arguments: [1]
            - arguments: [2]
            - arguments: [3]
        MESSAGE
      end
    end

    describe "using block" do
      it "asserts arguments depending on block returned value" do
        expect {
          create_worker_and_return_arguments
        }.to enqueue_sidekiq_jobs(SampleJob).with { |value| value }
      end

      it "fails assertion when arguments doesn't match block returned value" do
        expect {
          expect {
            create_worker_and_return_arguments
          }.to enqueue_sidekiq_jobs(SampleJob).with { |value| ["A"] }
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
          expected to enqueue SampleJob job
            arguments: ["A"]

          found 1 SampleJob:
            arguments: [1, 2, 3]
        MESSAGE
      end

      it "raises an error when returned value from block is not an Array" do
        expect {
          expect {
            create_worker_and_return_arguments
          }.to enqueue_sidekiq_jobs(SampleJob).with { |value| "A" }
        }.to raise_error(RuntimeError).with_message("arguments returned from a proc are expected to be an Array")
      end
    end
  end

  describe "schedule matching" do
    it "asserts that jobs will be enqueued in an interval" do
      expect {
        SampleJob.perform_in(5.minutes)
      }.to enqueue_sidekiq_jobs(SampleJob).in(5.minutes)
    end

    it "asserts that jobs will be enqueued at a given time" do
      expect {
        SampleJob.perform_in(5.minutes)
      }.to enqueue_sidekiq_jobs(SampleJob).at(5.minutes.from_now)
    end

    it "fails assertion when no jobs is enqueued in expected interval" do
      expect {
        expect {
          SampleJob.perform_in(5.minutes)
        }.to enqueue_sidekiq_jobs(SampleJob).in(10.minutes)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to enqueue SampleJob job
          in:        10 minutes (2022-08-10 00:10:00 +0200)

        found 1 SampleJob:
          at:        2022-08-10 00:05:00 +0200
      MESSAGE
    end

    it "fails assertion when no jobs is enqueued at a given time" do
      expect {
        expect {
          SampleJob.perform_in(5.minutes)
        }.to enqueue_sidekiq_jobs(SampleJob).at(10.minutes.from_now)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to enqueue SampleJob job
          at:        2022-08-10 00:10:00 +0200

        found 1 SampleJob:
          at:        2022-08-10 00:05:00 +0200
      MESSAGE
    end

    describe "negative matcher" do
      it "asserts that no jobs will be enqueued in an interval" do
        expect {
          SampleJob.perform_in(5.minutes)
        }.not_to enqueue_sidekiq_jobs(SampleJob).in(10.minutes)
      end

      it "asserts that no jobs will be enqueued at a given time" do
        expect {
          SampleJob.perform_in(5.minutes)
        }.not_to enqueue_sidekiq_jobs(SampleJob).at(10.minutes.from_now)
      end

      it "fails assertion when some jobs are enqueued in expected interval" do
        expect {
          expect {
            SampleJob.perform_in(5.minutes)
          }.not_to enqueue_sidekiq_jobs(SampleJob).in(5.minutes)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
          expected not to enqueue SampleJob job
            in:        5 minutes (2022-08-10 00:05:00 +0200)

          found 1 SampleJob:
            at:        2022-08-10 00:05:00 +0200
        MESSAGE
      end

      it "fails assertion when some jobs are enqueued at a given time" do
        expect {
          expect {
            SampleJob.perform_in(5.minutes)
          }.not_to enqueue_sidekiq_jobs(SampleJob).at(5.minutes.from_now)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
          expected not to enqueue SampleJob job
            at:        2022-08-10 00:05:00 +0200

          found 1 SampleJob:
            at:        2022-08-10 00:05:00 +0200
        MESSAGE
      end
    end
  end

  describe "counting jobs" do
    it "asserts that only one job will be enqueued" do
      expect {
        SampleJob.perform_async
      }.to enqueue_sidekiq_jobs(SampleJob).once
    end

    it "asserts that only two jobs will be enqueued" do
      expect {
        SampleJob.perform_async
        SampleJob.perform_async
      }.to enqueue_sidekiq_jobs(SampleJob).twice
    end

    it "asserts that an exact number of jobs will be enqueued" do
      expect {
        SampleJob.perform_async
        SampleJob.perform_async
      }.to enqueue_sidekiq_jobs(SampleJob).exactly(2).times
    end

    it "fails assertions when expecting only one job" do
      expect {
        expect {
          SampleJob.perform_async
          SampleJob.perform_async
        }.to enqueue_sidekiq_jobs(SampleJob).once
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to enqueue SampleJob job
          exactly:   1 time(s)

        found 2 SampleJob
      MESSAGE
    end

    it "fails assertions when expecting only two job" do
      expect {
        expect {
          SampleJob.perform_async
        }.to enqueue_sidekiq_jobs(SampleJob).twice
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to enqueue SampleJob job
          exactly:   2 time(s)

        found 1 SampleJob
      MESSAGE
    end

    it "fails assertions when expecting an exact number of jobs" do
      expect {
        expect {
          SampleJob.perform_async
          SampleJob.perform_async
        }.to enqueue_sidekiq_jobs(SampleJob).exactly(3).times
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to enqueue SampleJob job
          exactly:   3 time(s)

        found 2 SampleJob
      MESSAGE
    end
  end

  describe "combining counts, arguments and schedules" do
    it "asserts that an exact number of jobs will be enqueued with expected arguments" do
      expect {
        SampleJob.perform_bulk([[1], [2], [2], [2], [3], [3]])
        SampleJob.perform_in(10.minutes, 4)
      }
        .to  enqueue_sidekiq_jobs(SampleJob).exactly(7).times
        .and enqueue_sidekiq_jobs(SampleJob).once.with(1)
        .and enqueue_sidekiq_jobs(SampleJob).exactly(3).times.with(2)
        .and enqueue_sidekiq_jobs(SampleJob).twice.with(3)
    end

    it "fails assertion when none of the jobs matches expectations" do
      expect {
        expect {
          SampleJob.perform_in(15.minutes, 2)
          SampleJob.perform_in(15.minutes, 1)
          SampleJob.perform_in(15.minutes, 1)
          SampleJob.perform_in(10.minutes, 1)
        }.to enqueue_sidekiq_jobs(SampleJob).exactly(3).times.with(1).in(15.minutes)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to enqueue SampleJob job
          exactly:   3 time(s)
          arguments: [1]
          in:        15 minutes (2022-08-10 00:15:00 +0200)

        found 4 SampleJob:
          - arguments: [2]
            at:        2022-08-10 00:15:00 +0200
          - arguments: [1]
            at:        2022-08-10 00:15:00 +0200
          - arguments: [1]
            at:        2022-08-10 00:15:00 +0200
          - arguments: [1]
            at:        2022-08-10 00:10:00 +0200
      MESSAGE
    end
  end

  describe "batches matching" do
    it "asserts that a job is not included in a batch" do
      expect {
        SampleJob.perform_async
      }.to enqueue_sidekiq_jobs(SampleJob).without_batch
    end

    it "asserts that jobs is included in a batch" do
      batch = Sidekiq::Batch.new

      expect {
        batch.jobs do
          SampleJob.perform_async
        end
      }.to enqueue_sidekiq_jobs(SampleJob).within_batch
    end

    it "asserts that jobs is included in an expected batch" do
      batch = Sidekiq::Batch.new

      expect {
        batch.jobs do
          SampleJob.perform_async
        end
      }.to enqueue_sidekiq_jobs(SampleJob).within_batch(batch)
    end

    it "asserts that jobs is included in a batch with a given BID" do
      batch = Sidekiq::Batch.new

      expect {
        batch.jobs do
          SampleJob.perform_async
        end
      }.to enqueue_sidekiq_jobs(SampleJob).within_batch(batch.bid)
    end

    it "asserts that jobs is included in a batch that matches assertion" do
      batch = Sidekiq::Batch.new

      expect {
        batch.jobs do
          SampleJob.perform_async
        end
      }.to enqueue_sidekiq_jobs(SampleJob).within_batch(have_attributes(bid: batch.bid))
    end

    it "fails assertion when jobs is included in a batch" do
      batch = Sidekiq::Batch.new

      expect {
        expect {
          batch.jobs { SampleJob.perform_async }
        }.to enqueue_sidekiq_jobs(SampleJob).without_batch
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to enqueue SampleJob job
          batch:     no batch

        found 1 SampleJob:
          batch:     <Sidekiq::Batch bid: "#{batch.bid}">
      MESSAGE
    end

    it "fails assertion when jobs is not included in a batch" do
      expect {
        expect {
          SampleJob.perform_async
        }.to enqueue_sidekiq_jobs(SampleJob).within_batch
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to enqueue SampleJob job
          batch:     to be present

        found 1 SampleJob:
          batch:     no batch
      MESSAGE
    end

    it "fails assertion when expecting another batch" do
      batch1 = Sidekiq::Batch.new
      batch2 = Sidekiq::Batch.new

      expect {
        expect {
          batch1.jobs { SampleJob.perform_async }
        }.to enqueue_sidekiq_jobs(SampleJob).within_batch(batch2)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to enqueue SampleJob job
          batch:     <Sidekiq::Batch bid: "#{batch2.bid}">

        found 1 SampleJob:
          batch:     <Sidekiq::Batch bid: "#{batch1.bid}">
      MESSAGE
    end

    it "fails assertion when expecting a batch with another BID" do
      batch = Sidekiq::Batch.new

      expect {
        expect {
          batch.jobs { SampleJob.perform_async }
        }.to enqueue_sidekiq_jobs(SampleJob).within_batch("U2wgz8cxxTUdqg")
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to enqueue SampleJob job
          batch:     <Sidekiq::Batch bid: "U2wgz8cxxTUdqg">

        found 1 SampleJob:
          batch:     <Sidekiq::Batch bid: "#{batch.bid}">
      MESSAGE
    end

    it "fails assertion when expecting a batch matching an assertion" do
      batch = Sidekiq::Batch.new

      expected_message =
        if ENV["SUPER_DIFF"]
          <<~MESSAGE.strip
            expected to enqueue SampleJob job
              batch:     have attributes (bid: "U2wgz8cxxTUdqg")

            found 2 SampleJob:
              - batch:     <Sidekiq::Batch bid: "#{batch.bid}">
              - batch:     <Sidekiq::Batch bid: "#{batch.bid}">
          MESSAGE
        else
          <<~MESSAGE.strip
            expected to enqueue SampleJob job
              batch:     have attributes {:bid => "U2wgz8cxxTUdqg"}

            found 2 SampleJob:
              - batch:     <Sidekiq::Batch bid: "#{batch.bid}">
              - batch:     <Sidekiq::Batch bid: "#{batch.bid}">
          MESSAGE
        end

      expect {
        expect {
          batch.jobs do
            SampleJob.perform_async
            SampleJob.perform_async
          end
        }.to enqueue_sidekiq_jobs(SampleJob).within_batch(have_attributes(bid: "U2wgz8cxxTUdqg"))
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(expected_message)
    end
  end
end
