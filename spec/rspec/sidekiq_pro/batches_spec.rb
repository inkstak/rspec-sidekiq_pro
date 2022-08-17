# frozen_string_literal: true

require "spec_helper"

RSpec.describe RSpec::SidekiqPro::Batches do
  let(:sample_job_class) do
    Class.new do
      include Sidekiq::Job

      def perform(*args)
        # Do nothing
      end
    end
  end

  before do
    stub_const("SampleJob", Class.new(sample_job_class))
  end

  it "pushes batches into an in-memory objects" do
    batch = Sidekiq::Batch.new
    batch.jobs do
      SampleJob.perform_async
    end

    expect(described_class.size).to eq(1)
    expect(described_class.first).to include("bid" => batch.bid)
  end
end
