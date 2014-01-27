require "./lib/telemetry/span"
require "./lib/telemetry/helpers/id_maker"
require "./lib/telemetry/helpers/time_maker"
require "Socket"
require "pp"

module Telemetry
  class Tracer
    include Helpers::IdMaker
    include Helpers::TimeMaker

    attr_reader :spans, :id, :current_span, :root_span, :reason, :sample, :sample_size

    def initialize(opts={})
      check_dirty_bits(opts)
      @id = opts[:trace_id] || generate_id
      #current span in the context of this RPC call
      @current_span = Span.new({:id => opts[:parent_span_id]})
      @spans = [@current_span]
      @enabled = opts[:enabled]
      @log_instrumentation_time = opts[:log_instrumentation_time]
      @log_instrumentation_time = true if @log_instrumentation_time.nil?
      @sample, @sample_size = sample_and_size(opts[:sample])
      @host = opts[:run_on_hosts]
      @override = true
    end

    def sample_and_size(opts)
      (opts.nil? || opts.empty?) ? [1, 1024] : [opts[:number_of_requests], opts[:out_of]]
    end

    def dirty?
      !!@dirty
    end

    def enabled?
      !!@enabled
    end

    def log_instrumentation_time?
      !!@log_instrumentation_time
    end

    def annotate(params={})
      current_span.annotate(params)
    end

    def matching_host?
      @host.nil? ? true : !!(Socket.gethostname =~ /#{@host}/)
    end

    def override?
      @override
    end

    def override=(flag)
      @override = flag
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
