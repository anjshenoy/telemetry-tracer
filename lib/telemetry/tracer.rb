require "telemetry/span"
require "telemetry/runner"
require "telemetry/config"
require "telemetry/helper"
require "core/forwardable_ext"

module Telemetry
  class Tracer
    include Helpers::IdMaker
    include Helpers::TimeMaker
    include Helpers::Jsonifier
    extend SimpleForwardable

    attr_reader :spans, :id, :current_span, :runner

    delegate :run?, :override=, :to => :runner
    delegate :annotations, :annotate, :post_process, :to => :current_span

    def initialize(runner, sink, opts={})
      @runner = runner
      if run?
        @sink = sink
        trace_id, parent_span_id = opts["trace_id"], opts["parent_span_id"]
        check_dirty_bits(trace_id, parent_span_id)
        @id = trace_id || generate_id
        @current_span = Span.new({:id => parent_span_id, 
                                  :trace_id => @id,
                                  :name => opts["name"],
                                  :annotations => opts["annotations"]})
        @spans = [@current_span]
      end
      @in_progress = false
      @flushed = false
    end

    def dirty?
      !!@dirty
    end

    def in_progress?
      !!@in_progress
    end

    def start
      if run?
        @current_span.start
        @in_progress = true
      end
    end

    def stop
      if run?
        @spans.each(&:stop)
        @in_progress = false
        flush!
      end
    end

    def apply(&block)
      if run?
        start
        yield self
        stop
      else
        yield
      end
    end

    def start_new_span(name)
      span = Span.new({:parent_span_id => @current_span.id, 
                       :trace_id => id, 
                       :name => name})
      @spans << span
      @current_span = span
    end

    def to_hash
      {:id => id,
       :tainted => @reason,
       :current_span_id => @current_span.id,
       :spans => spans.map(&:to_hash)
      }
    end

    def flushed?
      !!@flushed
    end


    private
    def flush!
      @sink.process(self)
      @flushed = true
      self.class.reset
    end

    def check_dirty_bits(trace_id, parent_span_id)
      @dirty = false
      if (trace_id.nil? && !parent_span_id.nil?)
        @dirty = true
        @reason = "trace_id not present; parent_span_id present. Auto generating trace id"
      elsif (!trace_id.nil? && parent_span_id.nil?)
        @dirty = true
        @reason = "trace_id present; parent_span_id not present."
      end
      @dirty
    end

    class << self
      def current
        @tracer
      end

      def find_or_create(opts={})
        @tracer ||= build(opts)
      end

      def build(opts={})
        @config ||= Telemetry::Config.new(opts)
        new(@config.runner, @config.sink, opts)
      end

      def reset
        @tracer = nil
      end
    end
  end
end
