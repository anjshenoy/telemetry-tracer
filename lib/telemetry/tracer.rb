require "telemetry/span"
require "telemetry/runner"
require "telemetry/config"
require "telemetry/helper"
require "core/forwardable_ext"

module Telemetry
  class TraceProcessedException < Exception; end
  class ConfigNotApplied < Exception; end

  class Tracer
    include Helpers::IdMaker
    include Helpers::Jsonifier
    include Helpers::Timer
    extend SimpleForwardable

    attr_reader :id

    def initialize(opts)
      @in_progress = false
      @flushed = false
      @enabled = self.class.run?
      return if !enabled?

      instrument do
        @sink = self.class.config.sink
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

    def enabled?
      !!@enabled
    end

    def in_progress?
      !!@in_progress
    end

    def apply(span_name=nil, &block)
      start(span_name)
      yield self
      stop
    end

    def apply_with_annotation(span_name, key, value="", &block)
      annotate(key, value)
      apply(span_name, &block)
    end

    def apply_with_annotations(span_name, annotations, &block)
      annotations.each {|annotation| annotate(*annotation) }
      apply(span_name, &block)
    end

    def bump_current_span
      if @spans.size > 1
        current_span_index = @spans.index(@current_span)
        @current_span = @spans[current_span_index - 1]
      end
    end

    def to_hash
      return {} if !enabled?

      {:id => id,
       :tainted => @reason,
       :time_to_instrument_trace_bits_only => @instrumentation_time,
       :current_span_id => @current_span.id,
       :spans => @spans.map(&:to_hash)
      }
    end

    def current_span_id
      enabled? ? @current_span.id : nil
    end

    def apply_new_span(name=nil, &block)
      start_new_span.apply(name) do
        yield self
      end
    end

    def method_missing(sym, *args, &block)
      if [:annotate, :post_process].include?(sym)
          return (enabled? ? @current_span.send(sym, *args, &block) : nil)
      end
      super
    end

    private
    def start_new_span(name=nil)
      span = Span.new({:parent_span_id => @current_span.id, 
                       :tracer => self, 
                       :name => name})
      span.start
      @spans << span
      @current_span = span
    end

    def start(span_name=nil)
      return if !enabled?
      raise TraceProcessedException.new if flushed?
      instrument do
        @current_span.start(span_name)
        @in_progress = true
      end
    end

    def stop
      return if !enabled?
      raise TraceProcessedException.new if flushed?
      instrument do
        @spans.each do |span|
          span.stop unless span.stopped?
        end
      end
      flush!
    end

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

        reset if override? != flag && @tracer && !@tracer.in_progress?
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
