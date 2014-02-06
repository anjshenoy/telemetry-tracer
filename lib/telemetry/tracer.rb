require "./lib/telemetry/span"
require "./lib/telemetry/runner"
require "./lib/telemetry/helpers/id_maker"
require "./lib/telemetry/helpers/time_maker"
require "forwardable"

module Telemetry
  class Tracer
    include Helpers::IdMaker
    include Helpers::TimeMaker
    extend Forwardable

    attr_reader :spans, :id, :current_span, :root_span, :reason, :runner, :start_time, :stop_time

    def_delegator :@runner, :run?, :run?
    def_delegator :@runner, :override=, :override=
    def_delegator :@current_span, :annotations, :annotations

    def initialize(opts={})
      check_dirty_bits(opts)
      @id = opts[:trace_id] || generate_id
      #current span in the context of this RPC call
      @current_span = Span.new({:id => opts[:parent_span_id]})
      @spans = [@current_span]
      @runner = Runner.new(opts)
      @log_instrumentation_time = opts[:log_instrumentation_time]
      @log_instrumentation_time = true if @log_instrumentation_time.nil?
    end

    def dirty?
      !!@dirty
    end

    def log_instrumentation_time?
      !!@log_instrumentation_time
    end

    def annotate(params={})
      current_span.annotate(params)
    end

    def start
      @start_time = time
    end

    def stop
      if @start_time.nil?
        @dirty = true
      end
      @stop_time = time
    end

    def apply(&block)
      start
      yield self
      stop
    end

    private
    def check_dirty_bits(opts={})
      if (!opts[:trace_id] && opts[:parent_span_id]) 
        @dirty = true
        @reason = "trace_id not present; parent_span_id present. Auto generating trace id"
      elsif (opts[:trace_id] && !opts[:parent_span_id])
        @dirty = true
        @reason = "trace_id present; parent_span_id not present."
      end
    end

    class << self
      def current(opts={})
        @tracer ||= Tracer.new(opts)
      end
      alias_method :find_or_create, :current
    end
  end
end
