require "telemetry/span"
require "telemetry/runner"
require "telemetry/config"
require "telemetry/helper"
require "telemetry/helpers/timer"
require "core/forwardable_ext"
require "telemetry/instrumentation/zephyr"

module Telemetry
  class TraceFlushedException < Exception; end

  class Tracer
    include Helpers::IdMaker
    include Helpers::TimeMaker
    include Helpers::Jsonifier
    include Helpers::Timer
    extend SimpleForwardable

    attr_reader :spans, :id, :current_span, :runner

    delegate :run?, :override?, :override=, :sink, :to => :config
    delegate :annotations, :annotate, :post_process, :to => :current_span

    def config
      self.class.config
    end

    def initialize(opts)
      @in_progress = false
      @flushed = false
      return if !run?

      instrument do
        @sink = sink
        trace_id, parent_span_id = opts["trace_id"], opts["parent_span_id"]
        check_dirty_bits(trace_id, parent_span_id)
        @id = trace_id || generate_id
        @current_span = Span.new({:parent_span_id => parent_span_id, 
                                  :tracer => self,
                                  :name => opts["name"],
                                  :annotations => opts["annotations"]})
        @spans = [@current_span]
      end
    end

    def dirty?
      !!@dirty
    end

    def in_progress?
      !!@in_progress
    end

    def start(span_name=nil)
      raise TraceFlushedException.new if flushed?
      return if !run?
      instrument do
        @current_span.start(span_name)
        @in_progress = true
      end
    end

    def stop
      raise TraceFlushedException.new if flushed?
      return if !run?
      instrument do
        @spans.each do |span|
          span.stop unless span.stopped?
        end
        @in_progress = false
      end
      flush!
    end

    def apply(span_name=nil, &block)
      if run?
        start(span_name)
        yield self, current_span
        stop
      else
        yield
      end
    end

    def start_new_span(name=nil)
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

    def apply_new_span(name=nil, &block)
      start_new_span.apply(name) do |span|
        yield span
      end
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

      def config=(config_opts = {})
        @config ||= Telemetry::Config.new(config_opts)
      end

      def config
        @config
      end

      def with_config(config_opts = {})
        self.config = config_opts
        self
      end

      def with_override(flag = false)
        self.override = flag
        self
      end

      def method_missing(sym, *args, &block)
        if config.respond_to?(sym)
          return config.send(sym, *args, &block)
        end
        super
      end

      def find_or_create(opts={})
        self.config = {} if self.config.nil?
        @tracer ||= new(opts)
        @tracer

      end
      alias_method :fetch, :find_or_create

      #TODO: should reset just clear out trace's internals?
      #or just flat out nuke everything as below.
      def reset
        @tracer = nil
      end
    end
  end
end
