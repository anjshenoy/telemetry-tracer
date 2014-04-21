require "telemetry/span"
require "telemetry/runner"
require "telemetry/config"
require "telemetry/helper"
require "telemetry/helpers/timer"
require "core/forwardable_ext"
require "telemetry/instrumentation/zephyr"

module Telemetry
  class TraceProcessedException < Exception; end
  class ConfigNotApplied < Exception; end

  class Tracer
    include Helpers::IdMaker
    include Helpers::TimeMaker
    include Helpers::Jsonifier
    include Helpers::Timer
    extend SimpleForwardable

    attr_reader :spans, :id, :current_span, :runner

    delegate :sink, :to => :config

    def config
      self.class.config
    end

    def initialize(opts)
      @in_progress = false
      @flushed = false
      @run = self.class.run?
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

    def run?
      !!@run
    end

    def dirty?
      !!@dirty
    end

    def in_progress?
      !!@in_progress
    end

    def start(span_name=nil)
      raise TraceProcessedException.new if flushed?
      return if !run?
      instrument do
        @current_span.start(span_name)
        @in_progress = true
      end
    end

    #TODO: a trace should throw a NotStartedException
    # because starting a trace logs the start time
    # and stopping it records the duration of the span
    # which is pretty important
    def stop
      raise TraceProcessedException.new if flushed?
      return if !run?
      instrument do
        @spans.each do |span|
          span.stop unless span.stopped?
        end
      end
      flush!
    end

    #TODO: add a new method here apply_with_annotation
    #see application_controller for semantics
    def apply(span_name=nil, &block)
      if run?
        start(span_name)
        yield self, current_span
        stop
      else
        yield
      end
    end

    def apply_with_annotation(span_name, key, value="", &block)
      annotate(key, value)
      apply(span_name, &block)
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

    def apply_new_span(name=nil, &block)
      start_new_span.apply(name) do |span|
        yield span
      end
    end

    def method_missing(sym, *args, &block)
      if [:annotations, :annotate, :post_process_blocks, :post_process].include?(sym)
          return (run? ? current_span.send(sym, *args, &block) : nil)
      end
      super
    end

    private
    def flushed?
      !!@flushed
    end

    def flush!
      @sink.process(self)
      @flushed = true
      @in_progress = false
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

      # override is the secondary circuit breaker and should therefore
      # be applied on top of with_config. If config is not applied
      # by the time we get here, raise an exception.
      # The two possible states are:
      # 1. override is switched from off -> on (there is no currently executing trace)
      # 2. override is switched from on -> off (there is a currently executing trace, possibly in progress)
      #   a. if trace is in progress -> wait till it done processing i.e. 
      #       the stop method is called. We don't want to reset a trace that is not done.
      #       The important thing is that no new executable traces are created 
      #       as a result of switching from on -> off.
      #   b. if trace is not in progress i.e its been created but not started, 
      #       then its safe to reset it. There is the possibility of loosing a trace. 
      #       This trace will however no longer be valid by the time the override flag 
      #       is switched back on (even if this happens instantly i.e. the next command) 
      #       as the request-response cycle will likely have completed with time to spare.
      def with_override(flag = false)
        raise ConfigNotApplied if !config

        reset if override? != flag && current && !current.in_progress?
        config.override = flag
        self
      end
      alias_method :override=, :with_override

      def method_missing(sym, *args, &block)
        if config.respond_to?(sym)
          return config.send(sym, *args, &block)
        end
        super
      end

      def find_or_create(opts={})
        self.config = {} if self.config.nil?
        @tracer ||= new(opts)
      end
      alias_method :fetch, :find_or_create

      def reset
        @tracer = nil
      end
    end
  end
end
