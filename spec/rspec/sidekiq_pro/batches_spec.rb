# frozen_string_literal: true

require "spec_helper"

RSpec.describe RSpec::SidekiqPro::Batches do
  let(:sample_job_class) do
    Class.new do
      include Sidekiq::Job
    end
  end

  let!(:bids) do
    stub_const("SampleJob", Class.new(sample_job_class))

    4.times.map do |index|
      batch = Sidekiq::Batch.new
      batch.description = "Batch ##{index}"
      batch.jobs { SampleJob.perform_async }
      batch.bid
    end
  end

  it "pushes batches into an in-memory objects" do
    expect(described_class.size).to eq(4)
    expect(described_class).to be_any
  end

  it "allows to return first batch" do
    expect(described_class.first)
      .to be_a(Sidekiq::Batch)
      .and have_attributes("bid" => bids.first)
  end

  it "allows to return last batch" do
    expect(described_class.last)
      .to be_a(Sidekiq::Batch)
      .and have_attributes("bid" => bids.last)
  end

  it "allows to find a batch by BID" do
    expect(described_class[bids[1]])
      .to be_a(Sidekiq::Batch)
      .and have_attributes("bid" => bids[1])
  end

  it "allows to find a batch" do
    expect(described_class.find { |batch| batch.description == "Batch #2" })
      .to be_a(Sidekiq::Batch)
      .and have_attributes("bid" => bids[2])
  end

  it "iterates each batches" do
    expect { |b|
      described_class.each(&b)
    }.to yield_successive_args(Sidekiq::Batch, Sidekiq::Batch, Sidekiq::Batch, Sidekiq::Batch)
  end

  it "clears all batches" do
    described_class.clear_all

    expect(described_class.size).to eq(0)
    expect(described_class).to be_empty
  end
end
