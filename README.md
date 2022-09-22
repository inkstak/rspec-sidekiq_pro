# Rspec for Sidekiq Pro

[![Gem Version](https://badge.fury.io/rb/rspec-sidekiq_pro.svg)](https://rubygems.org/gems/rspec-sidekiq_pro)
[![CI Status](https://github.com/inkstak/rspec-sidekiq_pro/actions/workflows/ci.yml/badge.svg)](https://github.com/inkstak/rspec-sidekiq_pro/actions/workflows/ci.yml)
[![Maintainability](https://api.codeclimate.com/v1/badges/9bb8b75ea8c66b1a9c94/maintainability)](https://codeclimate.com/github/inkstak/rspec-sidekiq_pro/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/3de8ad4b1787cdb9ca20/test_coverage)](https://codeclimate.com/github/inkstak/rspec-sidekiq_pro/test_coverage)

### Installation

```bash
bundle add rspec-sidekiq_pro --group=test
```

### Configuration

`rspec/sidekiq_pro` requires `sidekiq/testing` by default so there is no need to include it.

It also means that Sidekiq in set to `fake` mode by default. Take a look at [Sidekiq wiki](https://github.com/mperham/sidekiq/wiki/Testing) for more details.

If you wish to start each spec without enqueued jobs or batches:

```ruby
require "rspec/sidekiq_pro"

RSpec.configure do |config|
  config.before do
    Sidekiq::Queues.clear_all
    RSpec::SidekiqPro::Batches.clear_all
  end
end
```

### Usage

Two matchers are provided:

* `enqueue_sidekiq_job` supports block expectation
* `have_enqueued_sidekiq_job` supports value expectation

```ruby
it do
  expect { SampleJob.perform_async }.to enqueue_sidekiq_job(SampleJob)
end
```
```ruby
it do
  SampleJob.perform_async
  expect(SampleJob).to have_enqueued_sidekiq_job
end
```

Both matchers provide the same chainable methods:

* `.with`
* `.once`
* `.twice`
* `.exactly().times`
* `.in`
* `.at`
* `.within_batch`
* `.without_batch`


#### Checking arguments

```ruby
it do
  expect { SampleJob.perform_async(1, 2, 3) }
    .to enqueue_sidekiq_job(SampleJob).with(1, 2, 3)
end
```
```ruby
it do
  SampleJob.perform_async(1, 2, 3)
  expect(SampleJob).to have_enqueued_sidekiq_job.with(1, 2, 3)
end
```


#### Checking counts

```ruby
it do
  expect { SampleJob.perform_async }
    .to enqueue_sidekiq_job(SampleJob).once
end
```

```ruby
it do
  expect { 
    2.times { SampleJob.perform_async }
  }.to enqueue_sidekiq_job(SampleJob).twice
end
```

```ruby
it do
  expect { 
    3.times { SampleJob.perform_async }
  }.to enqueue_sidekiq_job(SampleJob).exactly(3).times
end
```

Be careful when checking both counts and arguments:

```ruby
it do
  expect { 
    SampleJob.perform_async.with(1)
    SampleJob.perform_async.with(2)
  } 
    .to  enqueue_sidekiq_job(SampleJob).twice
    .and enqueue_sidekiq_job(SampleJob).once.with(1)
    .and enqueue_sidekiq_job(SampleJob).once.with(2)
end
```

#### Checking schedules

```ruby
it do
  expect { 
    SampleJob.perform_in(5.minutes)
  }.to enqueue_sidekiq_job(SampleJob).in(5.minutes)
end
```

```ruby
it do
  expect { 
    SampleJob.perform_at(10.minutes.from_now)
  }.to enqueue_sidekiq_job(SampleJob).at(10.minutes.from_now)
end
```

Time matching is performed to the second, if you have code that takes some time to be executed consider using [Timecop](https://github.com/travisjeffery/timecop).


#### Batches

```ruby
it do
  expect { 
    SampleJob.perform_async
  }.to enqueue_sidekiq_job(SampleJob).without_batch
end
```

```ruby
it do
  expect { 
    batch = Sidekiq::Batch.new
    batch.jobs { SampleJob.perform_async }
  }.to enqueue_sidekiq_job(SampleJob).within_batch
end
```

```ruby
it do
  expect { start_some_complex_workflow }
    .to enqueue_sidekiq_job(SampleJob).twice.within_batch { |batch|
      expect(batch).to have_attributes(description: "Complex Workflow first step")
    }
end
```

`within_batch` and `without_batch` require `Sidekiq::Testing` to be enabled.

When `Sidekiq::Testing` is enabled, every batch is pushed to `RSpec::SidekiqPro::Batches` instead of Redis.

```ruby
it do
  batch = Sidekiq::Batch.new
  batch.jobs { SampleJob.perform_async }

  expect(RSpec::SidekiqPro::Batches.first.bid).to eq(batch.bid)
end
```

## Contributing

1. Don't hesitate to submit your feature/idea/fix in [issues](https://github.com/inkstak/rspec-sidekiq_pro)
2. Fork the [repository](https://github.com/inkstak/rspec-sidekiq_pro)
3. Create your feature branch
4. Ensure RSpec & Rubocop are passing
4. Create a pull request

### Tests & lint

```bash
bundle exec rspec
bundle exec rubocop
```

Both can be run with:

```bash
bundle exec rake
```

## License & credits

Please see [LICENSE](https://github.com/inkstak/rspec-sidekiq_pro/blob/main/LICENSE) for further details.

Inspired by the [philostler/rspec-sidekiq](https://github.com/philostler/rspec-sidekiq/) & [pirj/rspec-enqueue_sidekiq_job](https://github.com/pirj/rspec-enqueue_sidekiq_job)

Contributors: [./graphs/contributors](https://github.com/inkstak/rspec-sidekiq_pro/graphs/contributors)
