# frozen_string_literal: true

require "spec_helper"

RSpec.describe RSpec::SidekiqPro::Matchers::HaveEnqueuedSidekiqJobs do
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
    SampleJob.perform_async
    SampleJob.perform_async
    expect(SampleJob).to have_enqueued_sidekiq_jobs
  end

  it "asserts that only one job will be enqueued" do
    SampleJob.perform_async
    expect(SampleJob).to have_enqueued_sidekiq_job
  end

  it "fails assertion when no jobs match" do
    expect {
      SampleJob2.perform_async
      SampleJob2.perform_async
      expect(SampleJob).to have_enqueued_sidekiq_jobs
    }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
      expected to have enqueued SampleJob job
      no SampleJob found
    MESSAGE
  end

  it "fails assertion when not only one job matches" do
    expect {
      SampleJob.perform_async
      SampleJob.perform_async
      expect(SampleJob).to have_enqueued_sidekiq_job
    }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
      expected to have enqueued SampleJob job
        exactly:   1 time(s)

      found 2 SampleJob
    MESSAGE
  end

  describe "negative matcher" do
    it "asserts that no jobs has been enqueued" do
      SampleJob2.perform_async
      SampleJob2.perform_async
      expect(SampleJob).not_to have_enqueued_sidekiq_jobs
    end

    it "asserts that not only one job has been enqueued" do
      SampleJob2.perform_async
      SampleJob2.perform_async
      expect(SampleJob).not_to have_enqueued_sidekiq_job
    end

    it "fails assertion when some jobs match" do
      expect {
        SampleJob.perform_async
        SampleJob.perform_async
        expect(SampleJob).not_to have_enqueued_sidekiq_jobs
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected not to have enqueued SampleJob job
        found 2 SampleJob
      MESSAGE
    end
  end

  describe "arguments matching" do
    it "asserts that arguments match" do
      SampleJob.perform_async(1, 2, 3)
      expect(SampleJob).to have_enqueued_sidekiq_jobs.with(1, 2, 3)
    end

    it "assets that even not-normalized arguments match" do
      SampleJob.perform_async("foo")
      expect(SampleJob).to have_enqueued_sidekiq_jobs.with(:foo)
    end

    it "asserts that arguments match against multiple jobs" do
      SampleJob.perform_async(1)
      SampleJob.perform_async(2)
      SampleJob.perform_async(3)
      expect(SampleJob).to have_enqueued_sidekiq_jobs.with(3)
    end

    it "fails assertion when the enqueued job doesn't match expected arguments" do
      expect {
        SampleJob.perform_async(1, 2, 3)
        expect(SampleJob).to have_enqueued_sidekiq_jobs.with(1)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to have enqueued SampleJob job
          arguments: [1]

        found 1 SampleJob:
          arguments: [1, 2, 3]
      MESSAGE
    end

    it "fails assertion when none of the enqueued jobs match expected arguments" do
      expect {
        SampleJob.perform_async(1)
        SampleJob.perform_async(2)
        SampleJob.perform_async(3)
        expect(SampleJob).to have_enqueued_sidekiq_jobs.with(4)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to have enqueued SampleJob job
          arguments: [4]

        found 3 SampleJob:
          - arguments: [1]
          - arguments: [2]
          - arguments: [3]
      MESSAGE
    end

    describe "negative matcher" do
      it "asserts that no jobs match the expected arguments" do
        SampleJob.perform_async(1)
        SampleJob.perform_async(2)
        SampleJob.perform_async(3)
        expect(SampleJob).not_to have_enqueued_sidekiq_jobs.with(4)
      end

      it "fails when some arguments match" do
        expect {
          SampleJob.perform_async(1)
          SampleJob.perform_async(2)
          SampleJob.perform_async(3)
          expect(SampleJob).not_to have_enqueued_sidekiq_jobs.with(3)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
          expected not to have enqueued SampleJob job
            arguments: [3]

          found 3 SampleJob:
            - arguments: [1]
            - arguments: [2]
            - arguments: [3]
        MESSAGE
      end
    end

    describe "using block" do
      it "raises an error when passing block to `with`" do
        expect {
          expect(SampleJob).to have_enqueued_sidekiq_jobs.with { |value| "A" }
        }.to raise_error(ArgumentError).with_message("setting block to `with` is not supported for this matcher")
      end
    end
  end

  describe "schedule matching" do
    it "asserts that jobs will be enqueued in an interval" do
      SampleJob.perform_in(5.minutes)
      expect(SampleJob).to have_enqueued_sidekiq_jobs.in(5.minutes)
    end

    it "asserts that jobs will be enqueued at a given time" do
      SampleJob.perform_in(5.minutes)
      expect(SampleJob).to have_enqueued_sidekiq_jobs.at(5.minutes.from_now)
    end

    it "asserts that schedule match the same second" do
      SampleJob.perform_in(5.minutes)
      Timecop.travel(0.05.seconds.from_now)
      expect(SampleJob).to have_enqueued_sidekiq_jobs.at(5.minutes.from_now)
    end

    it "fails assertion when one second elasped" do
      expect {
        SampleJob.perform_in(5.minutes)
        Timecop.travel(1.05.seconds.from_now)
        expect(SampleJob).to have_enqueued_sidekiq_jobs.at(5.minutes.from_now)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to have enqueued SampleJob job
          at:        2022-08-10 00:05:01 +0200

        found 1 SampleJob:
          at:        2022-08-10 00:05:00 +0200
      MESSAGE
    end

    it "fails assertion when no jobs is enqueued in expected interval" do
      expect {
        SampleJob.perform_in(5.minutes)
        expect(SampleJob).to have_enqueued_sidekiq_jobs.in(10.minutes)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to have enqueued SampleJob job
          in:        10 minutes (2022-08-10 00:10:00 +0200)

        found 1 SampleJob:
          at:        2022-08-10 00:05:00 +0200
      MESSAGE
    end

    it "fails assertion when no jobs is enqueued at a given time" do
      expect {
        SampleJob.perform_in(5.minutes)
        expect(SampleJob).to have_enqueued_sidekiq_jobs.at(10.minutes.from_now)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to have enqueued SampleJob job
          at:        2022-08-10 00:10:00 +0200

        found 1 SampleJob:
          at:        2022-08-10 00:05:00 +0200
      MESSAGE
    end

    describe "negative matcher" do
      it "asserts that no jobs will be enqueued in an interval" do
        SampleJob.perform_in(5.minutes)
        expect(SampleJob).not_to have_enqueued_sidekiq_jobs.in(10.minutes)
      end

      it "asserts that no jobs will be enqueued at a given time" do
        SampleJob.perform_in(5.minutes)
        expect(SampleJob).not_to have_enqueued_sidekiq_jobs.at(10.minutes.from_now)
      end

      it "fails assertion when some jobs are enqueued in expected interval" do
        expect {
          SampleJob.perform_in(5.minutes)
          expect(SampleJob).not_to have_enqueued_sidekiq_jobs.in(5.minutes)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
          expected not to have enqueued SampleJob job
            in:        5 minutes (2022-08-10 00:05:00 +0200)

          found 1 SampleJob:
            at:        2022-08-10 00:05:00 +0200
        MESSAGE
      end

      it "fails assertion when some jobs are enqueued at a given time" do
        expect {
          SampleJob.perform_in(5.minutes)
          expect(SampleJob).not_to have_enqueued_sidekiq_jobs.at(5.minutes.from_now)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
          expected not to have enqueued SampleJob job
            at:        2022-08-10 00:05:00 +0200

          found 1 SampleJob:
            at:        2022-08-10 00:05:00 +0200
        MESSAGE
      end
    end
  end

  describe "counting jobs" do
    it "asserts that only one job will be enqueued" do
      SampleJob.perform_async
      expect(SampleJob).to have_enqueued_sidekiq_jobs.once
    end

    it "asserts that only two jobs will be enqueued" do
      SampleJob.perform_async
      SampleJob.perform_async
      expect(SampleJob).to have_enqueued_sidekiq_jobs.twice
    end

    it "asserts that an exact number of jobs will be enqueued" do
      SampleJob.perform_async
      SampleJob.perform_async
      expect(SampleJob).to have_enqueued_sidekiq_jobs.exactly(2).times
    end

    it "fails assertions when expecting only one job" do
      expect {
        SampleJob.perform_async
        SampleJob.perform_async
        expect(SampleJob).to have_enqueued_sidekiq_jobs.once
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to have enqueued SampleJob job
          exactly:   1 time(s)

        found 2 SampleJob
      MESSAGE
    end

    it "fails assertions when expecting only two job" do
      expect {
        SampleJob.perform_async
        expect(SampleJob).to have_enqueued_sidekiq_jobs.twice
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to have enqueued SampleJob job
          exactly:   2 time(s)

        found 1 SampleJob
      MESSAGE
    end

    it "fails assertions when expecting an exact number of jobs" do
      expect {
        SampleJob.perform_async
        SampleJob.perform_async
        expect(SampleJob).to have_enqueued_sidekiq_jobs.exactly(3).times
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to have enqueued SampleJob job
          exactly:   3 time(s)

        found 2 SampleJob
      MESSAGE
    end
  end

  describe "combining counts, arguments and schedules" do
    it "asserts that an exact number of jobs will be enqueued with expected arguments" do
      SampleJob.perform_bulk([[1], [2], [2], [2], [3], [3]])
      SampleJob.perform_in(10.minutes, 4)

      expect(SampleJob)
        .to  have_enqueued_sidekiq_jobs.exactly(7).times
        .and have_enqueued_sidekiq_jobs.once.with(1)
        .and have_enqueued_sidekiq_jobs.exactly(3).times.with(2)
        .and have_enqueued_sidekiq_jobs.twice.with(3)
    end

    it "fails assertion when none of the jobs matches expectations" do
      expect {
        SampleJob.perform_in(15.minutes, 2)
        SampleJob.perform_in(15.minutes, 1)
        SampleJob.perform_in(15.minutes, 1)
        SampleJob.perform_in(10.minutes, 1)
        expect(SampleJob).to have_enqueued_sidekiq_jobs.exactly(3).times.with(1).in(15.minutes)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to have enqueued SampleJob job
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
      SampleJob.perform_async

      expect(SampleJob).to have_enqueued_sidekiq_jobs.without_batch
    end

    it "asserts that jobs is included in a batch" do
      batch = Sidekiq::Batch.new
      batch.jobs do
        SampleJob.perform_async
      end
      expect(SampleJob).to have_enqueued_sidekiq_jobs.within_batch
    end

    it "asserts that jobs is included in an expected batch" do
      batch = Sidekiq::Batch.new
      batch.jobs do
        SampleJob.perform_async
      end
      expect(SampleJob).to have_enqueued_sidekiq_jobs.within_batch(batch)
    end

    it "asserts that jobs is included in a batch with a given BID" do
      batch = Sidekiq::Batch.new
      batch.jobs do
        SampleJob.perform_async
      end
      expect(SampleJob).to have_enqueued_sidekiq_jobs.within_batch(batch.bid)
    end

    it "asserts that jobs is included in a batch that matches assertion" do
      batch = Sidekiq::Batch.new
      batch.jobs do
        SampleJob.perform_async
      end
      expect(SampleJob).to have_enqueued_sidekiq_jobs.within_batch(have_attributes(bid: batch.bid))
    end

    it "fails assertion when jobs is included in a batch" do
      batch = Sidekiq::Batch.new

      expect {
        batch.jobs { SampleJob.perform_async }
        expect(SampleJob).to have_enqueued_sidekiq_jobs.without_batch
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to have enqueued SampleJob job
          batch:     no batch

        found 1 SampleJob:
          batch:     <Sidekiq::Batch bid: "#{batch.bid}">
      MESSAGE
    end

    it "fails assertion when jobs is not included in a batch" do
      expect {
        SampleJob.perform_async
        expect(SampleJob).to have_enqueued_sidekiq_jobs.within_batch
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to have enqueued SampleJob job
          batch:     to be present

        found 1 SampleJob:
          batch:     no batch
      MESSAGE
    end

    it "fails assertion when expecting another batch" do
      batch1 = Sidekiq::Batch.new
      batch2 = Sidekiq::Batch.new

      expect {
        batch1.jobs { SampleJob.perform_async }
        expect(SampleJob).to have_enqueued_sidekiq_jobs.within_batch(batch2)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to have enqueued SampleJob job
          batch:     <Sidekiq::Batch bid: "#{batch2.bid}">

        found 1 SampleJob:
          batch:     <Sidekiq::Batch bid: "#{batch1.bid}">
      MESSAGE
    end

    it "fails assertion when expecting a batch with another BID" do
      batch = Sidekiq::Batch.new

      expect {
        batch.jobs { SampleJob.perform_async }
        expect(SampleJob).to have_enqueued_sidekiq_jobs.within_batch("U2wgz8cxxTUdqg")
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(<<~MESSAGE.strip)
        expected to have enqueued SampleJob job
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
            expected to have enqueued SampleJob job
              batch:     have attributes (bid: "U2wgz8cxxTUdqg")

            found 2 SampleJob:
              - batch:     <Sidekiq::Batch bid: "#{batch.bid}">
              - batch:     <Sidekiq::Batch bid: "#{batch.bid}">
          MESSAGE
        else
          <<~MESSAGE.strip
            expected to have enqueued SampleJob job
              batch:     have attributes {:bid => "U2wgz8cxxTUdqg"}

            found 2 SampleJob:
              - batch:     <Sidekiq::Batch bid: "#{batch.bid}">
              - batch:     <Sidekiq::Batch bid: "#{batch.bid}">
          MESSAGE
        end

      expect {
        batch.jobs do
          SampleJob.perform_async
          SampleJob.perform_async
        end
        expect(SampleJob).to have_enqueued_sidekiq_jobs.within_batch(have_attributes(bid: "U2wgz8cxxTUdqg"))
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError).with_message(expected_message)
    end
  end
end
