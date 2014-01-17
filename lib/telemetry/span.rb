require "./lib/telemetry/helpers/id_maker"
require "./lib/telemetry/helpers/time_maker"
require "./lib/telemetry/annotation"

module Telemetry
  class Span
    include Helpers::IdMaker
    include Helpers::TimeMaker

    attr_reader :id, :parent_span_id, :trace_id, :name, :annotations, :start_time

    def initialize(opts={})
      @parent_span_id = opts[:parent_span_id]
      @id = generate_id
      @trace_id = opts[:trace_id]
      @name = opts[:name]
      @annotations = []
      @start_time = time
    end

    def root?
      @parent_span_id.nil?
    end

    def annotate(params={})
      @annotations << Annotation.new(params)
    end

  end
end
