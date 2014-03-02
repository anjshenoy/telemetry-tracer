require "telemetry/span"
require "telemetry/runner"
require "telemetry/config"
require "telemetry/helper"
require "telemetry/helpers/timer"
require "core/forwardable_ext"

module Telemetry
  class TraceFlushedException < Exception; end

  class Tracer
    include Helpers::IdMaker
    include Helpers::TimeMaker
    include Helpers::Jsonifier
    include Helpers::Timer
    extend SimpleForwardable

    attr_reader :spans, :id, :current_span, :runner

    delegate :run?, :override=, :to => :runner
    delegate :annotations, :annotate, :post_process, :to => :current_span

    def initialize(runner, sink, opts={})
      @runner = runner
      if run?
        instrument do
          @sink = sink
          trace_id, parent_span_id = opts["trace_id"], opts["parent_span_id"]
          check_dirty_bits(trace_id, parent_span_id)
          @id = trace_id || generate_id
          @current_span = Span.new({:id => parent_span_id, 
                                    :tracer => self,
                                    :name => opts["name"],
                                    :annotations => opts["annotations"]})
          @spans = [@current_span]
        end
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
      raise TraceFlushedException.new if flushed?
      if run?
        instrument do
          @current_span.start
          @in_progress = true
        end
      end
    end

    def stop
      raise TraceFlushedException.new if flushed?
      if run?
        instrument do
          @spans.each(&:stop)
          @in_progress = false
        end
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
                       :tracer => self, 
                       :name => name})
      span.start
      @spans << span
      @current_span = span
    end

    def bump_current_span
      if spans.size > 1
        current_span_index = spans.index(current_span)
        @current_span = spans[current_span_index - 1]
      end
    end

    def to_hash
      return {} if !run?
      {:id => id.to_s,
       :tainted => @reason,
       :time_to_instrument_trace_bits_only => @instrumentation_time,
       :current_span_id => @current_span.id.to_s,
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
