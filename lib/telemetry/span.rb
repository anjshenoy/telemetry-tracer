require "telemetry/helper"
require "telemetry/annotation"
require "telemetry/processor"

module Telemetry
  SpanStoppedException = Class.new(Exception)

  class Span
    include Helpers::IdMaker
    include Helpers::TimeMaker

    attr_reader :id, :parent_span_id, :trace_id, :name, :annotations, 
      :start_time, :duration, :pid, :hostname, :processors

    def initialize(opts={})
      @parent_span_id = opts[:parent_span_id]
      @id = generate_id
      @trace_id = opts[:trace_id]
      @tainted = opts[:tainted]
      @name = opts[:name]
      @annotations = []
      add_annotations(opts[:annotations] || {})
      @pid = Process.pid
      @hostname = Socket.gethostname
      @processors = []
    end

    def root?
      @parent_span_id.nil?
    end

    def annotate(key, message)
      raise SpanStoppedException if stopped?
      @annotations << Annotation.new({key => message})
    end

    #ignore if blank option means log result even if 
    #its nil or empty by default.
    def post_process(name, ignore_if_blank = false, &block)
      @processors << Processor.new(name, ignore_if_blank, &block)
    end

    def stopped?
      !!@stop_time
    end

    def root?
      @parent_span_id.nil?
    end

    def tainted?
      !@tainted.nil?
    end

    def to_hash
      hash = {:span_id => id,
              :trace_id => trace_id,
              :parent_span_id => parent_span_id,
              :name => name,
              :start_time => start_time,
              :duration => duration,
              :annotations => annotations.map(&:to_hash)}

      #only root span gets metadata
      hash.merge!({:tainted => @tainted}) if tainted?
      root? ? hash.merge(root_span_metadata) : hash
    end

    def instrumentation_time=(instrumentation_time)
      @instrumentation_time = instrumentation_time
    end

    def in_progress?
      !!@in_progress
    end

    def name=(name)
      raise SpanStoppedException if stopped?
      @name = name if name
    end

    def start(name=nil)
      raise SpanStoppedException if stopped?
      @name ||= name
      @start_time = time
      @in_progress = true
    end

    def stop
      raise SpanStoppedException if stopped?
      @stop_time = time
      @in_progress = false
    end

    def apply(name=nil, &block)
      start(name)
      yield self
      stop
    end

    def duration
      (stopped? ? (@stop_time - @start_time) : "NaN")
    end

    def run_post_process!
      @annotations += processors.map(&:run).compact.map do |hash|
        instrumentation_time = hash.delete(:instrumentation_time)
        exception = hash.delete(:exception)
        if exception
          Telemetry::Config.error_logger.error("Error processing annotation for trace_id: #{@trace_id}, span_id: #{self.id} " + exception)
        end
        Annotation.new(hash, instrumentation_time)
      end
    end

    private
    def add_annotations(annotations_hash)
      annotations_hash.each {|k, v| annotate(k, v) }
    end

    def root_span_metadata
      metadata = {:pid => pid, :hostname => hostname}

      instrumentation_hash = @instrumentation_time.nil? ? {} : {:time_to_instrument_trace_bits_only => @instrumentation_time}
      metadata.merge!(instrumentation_hash)
    end

  end
end
