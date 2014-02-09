require "./lib/telemetry/helpers/id_maker"
require "./lib/telemetry/helpers/time_maker"
require "./lib/telemetry/helpers/jsonifier"
require "./lib/telemetry/annotation"

module Telemetry
  class Span
    include Helpers::IdMaker
    include Helpers::TimeMaker
    include Helpers::Jsonifier

    attr_reader :id, :parent_span_id, :trace_id, :name, :annotations, 
      :start_time, :stop_time, :pid, :hostname

    def initialize(opts={})
      @parent_span_id = opts[:parent_span_id]
      @id = generate_id
      @trace_id = opts[:trace_id]
      @name = opts[:name]
      @annotations = []
      add_annotations(opts[:annotations] || {})
      @pid = Process.pid
      @hostname = Socket.gethostname
    end

    def root?
      @parent_span_id.nil?
    end

    def annotate(key, message="")
      @annotations << Annotation.new({key => message})
    end

    def add_annotations(annotations_hash)
      annotations_hash.each {|k, v| annotate(k, v) }
    end

    def to_hash
      {:id => id,
       :pid => pid,
       :hostname => hostname,
       :parent_span_id => parent_span_id,
       :name => name,
       :start_time => start_time,
       :annotations => annotations.map(&:to_hash) }
    end

    def start
      @start_time = time
    end

    def stop
      @stop_time = time
    end

  end
end
