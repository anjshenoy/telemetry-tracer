require "json"
require "telemetry/span"
require "telemetry/runner"
require "telemetry/config"
require "telemetry/helper"
require "core/forwardable_ext"
require "telemetry/instrumentation/zephyr"
require "telemetry/instrumentation/sweatshop/worker"

#TODO:
# * rename to trace instead of tracer
# * when trace/span_id are provided, create a new span 
#   with the same ID as the span id and mark it as the callee

module Telemetry

  TRACE_HEADER_KEY = "X-Telemetry-TraceId"
  SPAN_HEADER_KEY = "X-Telemetry-SpanId"

  class TraceProcessedException < Exception; end
  class ConfigNotApplied < Exception; end

  class Tracer
    include Helpers::IdMaker
    include Helpers::Timer
    extend SimpleForwardable

    attr_reader :id

    def initialize(opts = {})
      @in_progress = false
      @flushed = false
      @enabled = (opts["run_basic_mode"] == true) ? self.class.run_basic? : self.class.run?
      return if !enabled?

      instrument do
        @sink = self.class.config.sink
        trace_id =  opts[TRACE_HEADER_KEY]
        parent_span_id = opts[SPAN_HEADER_KEY]
        check_dirty_bits(trace_id, parent_span_id)
        @id = trace_id || generate_id
        @current_span = Span.new({:parent_span_id => parent_span_id, 
                                  :trace_id => id,
                                  :name => opts["name"],
                                  :tainted => @reason,
                                  :annotations => opts["annotations"]})
        @root_span = @current_span
        @spans = [@current_span]
      end
    end

    def enabled?
      !!@enabled
    end

    def in_progress?
      !!@in_progress
    end

    def apply(span_name=nil, annotations=[], &block)
      begin
        start(span_name)
        annotations.each {|annotation| annotate(*annotation) }
        yield self
      rescue Exception => ex
        raise ex
      ensure
        stop
      end
    end

    def spans
      return [] if !enabled?

      @root_span.instrumentation_time = @instrumentation_time
      @spans.map(&:to_hash)
    end

    def to_json
      spans.map(&:to_json).join("\n")
    end

    def current_span_id
      enabled? ? @current_span.id : nil
    end

    def annotate(*args)
      return nil if !enabled?
      @current_span.annotate(*args)
    end

    def post_process(*args, &block)
      return nil if !enabled?
      @current_span.post_process(*args, &block)
    end

    def headers
      if enabled?
        {TRACE_HEADER_KEY => id,
         SPAN_HEADER_KEY  => current_span_id}
      else
        {}
      end
    end

    private
    def bump_current_span
      @current_span = @spans.select{|s| s.in_progress?}.last
      @current_span ||= @spans.first
    end

    def trace_processed_error_string
      "already processed trace_id:#{id}, span_id: #{current_span_id}"
    end

    def start_new_span(name=nil)
      span = Span.new({:parent_span_id => @current_span.id, 
                       :trace_id => id, 
                       :name => name})
      span.start
      @spans << span
      @current_span = span
    end

    #if a trace has already started, apply a new span
    #if its stopped, throw the TraceProcessedException
    def start(span_name=nil)
      return if !enabled?
      raise TraceProcessedException.new(trace_processed_error_string) if flushed?
      if in_progress?
        start_new_span(span_name)
      end
      instrument do
        @current_span.start(span_name)
        @in_progress = true
      end
    end

    def stop
      return if !enabled?
      raise TraceProcessedException.new(trace_processed_error_string) if flushed?
      instrument do
        @current_span.stop
        bump_current_span
      end
      flush! if @spans.all?(&:stopped?)
    end

    def flushed?
      !!@flushed
    end

    def flush!
      instrument do
        @spans.each(&:run_post_process!)
      end
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
      def with_override(flag)
        raise ConfigNotApplied if !config

        reset if @tracer && !@tracer.in_progress?
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

      def fetch(opts = {})
        self.config = {} if self.config.nil?
        @tracer ||= new(opts)
      end

      def fetch_with_run_basic_mode(opts = {})
        fetch(opts.merge!({"run_basic_mode" => true}))
      end

      def current_trace_headers
        fetch.headers
      end

      def reset
        @tracer = nil
      end
    end
  end
end
