require "telemetry/helper"
require "telemetry/annotation"
require "celluloid"

module Telemetry
  SpanStoppedException = Class.new(Exception)

  class Span
    include Helpers::IdMaker
    include Helpers::TimeMaker
    include Helpers::Jsonifier

    attr_reader :id, :parent_span_id, :tracer, :name, :annotations, 
      :start_time, :duration, :pid, :hostname, :post_process_blocks

    def initialize(opts={})
      @parent_span_id = opts[:parent_span_id]
      @id = generate_id
      @tracer = opts[:tracer]
      @name = opts[:name]
      @annotations = []
      add_annotations(opts[:annotations] || {})
      @pid = Process.pid
      @hostname = Socket.gethostname
      @post_process_blocks = {}
    end

    def root?
      @parent_span_id.nil?
    end

    def annotate(key, message, instrumentation_time = nil, ignore_if_blank = true)
      if !!ignore_if_blank
        if !message.to_s.empty?
          annotate_with_time(key,  message, time)
        end
      else
        annotate_with_time(key,  message, time)
      end
    end

    def post_process(name, &block)
      @post_process_blocks.merge!({name => Celluloid::Future.new(&block)})
    end

    def add_annotations(annotations_hash)
      annotations_hash.each {|k, v| annotate(k, v) }
    end

    def stopped?
      !!@stop_time
    end

    def to_hash
      {:id => id.to_s,
       :pid => pid,
       :hostname => hostname,
       :parent_span_id => parent_span_id,
       :name => name,
       :start_time => start_time.to_s,
       :duration => duration,
       :annotations => annotations.map(&:to_hash),
      }
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
      @name = name if !name.nil?
      @start_time = time
      @in_progress = true
    end

    def stop
      raise SpanStoppedException if stopped?
      @stop_time = time
      run_post_process!
      @in_progress = false
      tracer.bump_current_span
    end

    def apply(name=nil, &block)
      start(name)
      yield self
      stop
    end

    def duration
      if stopped?
        @stop_time - @start_time
      end
    end

    private
    def annotate_with_time(key, message, time)
      @annotations << Annotation.new({key => message}, time)
    end

    def run_post_process!
      post_process_blocks.each_pair do |key, future|
        message, instrumentation_time = execute_future(future)
        annotate(key, message, instrumentation_time)
      end
    end

    def execute_future(future)
      old_time = time
      begin
        value = future.value
      rescue Exception => ex
        message = "Error processing annotation for trace_id: #{@tracer.id}, span_id: #{self.id}" + 
                   ex.class.to_s + ": " + ex.message + "\n" + ex.backtrace.join("\n")
        Telemetry::Logger.error_logger.error(message)
        value = "processing_error"
      end
      [value, (time - old_time)]
    end

  end
end
