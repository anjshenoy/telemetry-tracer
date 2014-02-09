require "./lib/telemetry/span"
require "./lib/telemetry/runner"
require "./lib/telemetry/config"
require "./lib/telemetry/helpers/id_maker"
require "./lib/telemetry/helpers/time_maker"
require "./lib/telemetry/helpers/jsonifier"
require "forwardable"

module Telemetry
  class Tracer
    include Helpers::IdMaker
    include Helpers::TimeMaker
    include Helpers::Jsonifier
    extend Forwardable

    attr_reader :spans, :id, :current_span, :root_span, :reason, :runner, 
      :start_time, :stop_time, :flushed

    def_delegator :@runner, :run?, :run?
    def_delegator :@runner, :override=, :override=
    def_delegator :@current_span, :annotations, :annotations

    def initialize(runner, trace_id, parent_span_id, sink)
      @runner = runner
      if run?
        check_dirty_bits(trace_id, parent_span_id)
        @id = trace_id || generate_id
        @current_span = Span.new({:id => parent_span_id, 
                                  :trace_id => @id})
        @spans = [@current_span]
        @sink = sink
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

    def annotate(key, message="")
      current_span.annotate(key, message)
    end

    def start
      if run?
        @current_span.start
        @in_progress = true
      end
    end

    def stop
      if run?
        @current_span.stop
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
       :start_time => start_time,
       :stop => stop_time,
       :current_span_id => @current_span.id,
       :spans => spans.map(&:to_hash)}
    end

    def flushed?
      !!@flushed
    end

    def flush!
      @flushed = true
      @sink.process(self)
    end


    private
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
      def current(opts={})
        @tracer ||= build(opts)
      end
      alias_method :find_or_create, :current

      def build(opts={})
        @config = Telemetry::Config.new(opts)
        new(@config.runner, opts[:trace_id], opts[:parent_span_id], @config.sink)
      end
    end
  end
end
