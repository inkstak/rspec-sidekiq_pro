# frozen_string_literal: true

module RSpec
  module SidekiqPro
    module Batches
      module Props
        class << self
          delegate :size, :first, :last, :each, :empty?, :any?, :none?, to: :batches_array
          delegate :fetch, to: :batches_hash

          def [](key)
            if key.is_a?(Numeric)
              batches_array[key]
            else
              batches_hash[key]
            end
          end

          def []=(bid, batch)
            batch["bid"] = bid
            batches_array << batch
            batches_hash[bid] = batch
          end

          def delete(bid)
            batch = batches_hash.delete(bid)
            batches_array.delete(batch)
          end

          def clear_all
            batches_array.clear
            batches_hash.clear
          end

          def to_a
            batches_array
          end

          def to_h
            batches_hash
          end

          private

          def batches_array
            @batches_array ||= []
          end

          def batches_hash
            @batches_hash ||= {}
          end
        end
      end

      class << self
        delegate :size, :delete, :clear_all, :empty?, :any?, :none?, to: Props
        delegate_missing_to :each

        def each
          return to_enum(:each) unless block_given?

          Props.each do |props|
            yield Sidekiq::Batch.new(props["bid"])
          end
        end

        def [](key)
          Sidekiq::Batch.new(Props[key]["bid"])
        end

        def first
          Sidekiq::Batch.new(Props.first["bid"])
        end

        def last
          Sidekiq::Batch.new(Props.last["bid"])
        end
      end
    end
  end
end

module Sidekiq
  class Batch
    def initialize(bid = nil)
      if Sidekiq::Testing.disabled?
        super
      else
        @bid  = bid || SecureRandom.urlsafe_base64(10)
        props = RSpec::SidekiqPro::Batches::Props.fetch(bid, {})

        @created_at  = props.fetch("created_at", Time.now.utc).to_f
        @description = props["description"]
        @parent_bid  = props["parent"]
        @callbacks   = props.fetch("callbacks", {})
        @jids        = props.fetch("jids", [])
        @mutable     = props.empty?
      end
    end

    def redis(bid, &block)
      return super if Sidekiq::Testing.disabled?

      raise "Redis unavailbale when Sidekiq::Testing is enable"
    end

    def jids
      return super if Sidekiq::Testing.disabled?

      @jids
    end

    def include?(jid)
      return super if Sidekiq::Testing.disabled?

      @jids.include?(jid)
    end

    def invalidate_all
      return super if Sidekiq::Testing.disabled?

      RSpec::SidekiqPro::Batches::Props[bid]["invalidated"] = true
      Sidekiq::Queues.jobs_by_queue.each_value { |jobs| jobs.delete_if { |job| include?(job["jid"]) } }
      Sidekiq::Queues.jobs_by_class.each_value { |jobs| jobs.delete_if { |job| include?(job["jid"]) } }
    end

    def invalidate_jids(*jids)
      return super if Sidekiq::Testing.disabled?

      # TODO
    end

    def invalidated?
      return super if Sidekiq::Testing.disabled?

      !!RSpec::SidekiqPro::Batches::Props[bid]["invalidated"]
    end

    def jobs(&block)
      return super if Sidekiq::Testing.disabled?

      raise ArgumentError, "Must specify a block" unless block

      if mutable?
        @parent_bid = Thread.current[:sidekiq_batch]&.bid

        RSpec::SidekiqPro::Batches::Props[bid] = {
          "created_at" => created_at,
          "description" => description,
          "parent" => parent_bid,
          "callbacks" => callbacks,
          "jids" => jids
        }
      end

      @mutable = false

      begin
        parent = Thread.current[:sidekiq_batch]
        Thread.current[:sidekiq_batch] = self
        yield
      ensure
        Thread.current[:sidekiq_batch] = parent
      end

      RSpec::SidekiqPro::Batches::Props[bid]["jids"] = @jids
    end

    def register(jid)
      return super if Sidekiq::Testing.disabled?

      @jids << jid
    end

    def perform_callback(event)
      raise NotImplementedError if Sidekiq::Testing.disabled?

      callbacks[event.to_s]&.each do |callback|
        callback.each do |target, options|
          klass_name, method = target.to_s.split("#")
          klass = klass_name.constantize
          meth  = method || "on_#{event}"
          inst  = klass.new
          inst.jid = SecureRandom.hex(12) if inst.respond_to?(:jid)
          inst.send(meth, status, options)
        end
      end
    end

    class Status
      def initialize(bid)
        if Sidekiq::Testing.disabled?
          super
        else
          @bid      = bid
          @props    = RSpec::SidekiqPro::Batches::Props.fetch(bid, {})
          @pending  = 0
          @failures = 0
          @total    = @props.fetch("jids", []).size
        end
      end
    end
  end
end
