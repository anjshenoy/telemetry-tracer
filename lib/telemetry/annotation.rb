require "./lib/telemetry/helpers/time_maker"
require "./lib/telemetry/helpers/jsonifier"

module Telemetry
  class Annotation
    include Helpers::TimeMaker
    include Helpers::Jsonifier

    attr_reader :params, :log_time, :instrumentation_time

    def initialize(params={}, instrumentation_time=nil)
      @params = params
      @log_time = time
      if !instrumentation_time.nil?
        @instrumentation_time = instrumentation_time
      end
    end

    def to_hash
      hash = params.merge({:time => log_time})
      if !instrumentation_time.nil?
        hash.merge!({:instrumentation_time => instrumentation_time})
      end
      hash
    end
  end
end
