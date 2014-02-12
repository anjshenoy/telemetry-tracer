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

    attr_reader :spans, :id, :current_span, :runner

    def_delegator :@runner, :run?, :run?
    def_delegator :@runner, :override=, :override=
    def_delegator :@current_span, :annotations, :annotations
    def_delegator :@current_span, :annotate, :annotate

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
        @config ||= Telemetry::Config.new(opts)
        new(@config.runner, @config.sink, opts)
      end
    end
  end
end
