require "./lib/telemetry/helpers/time_maker"
require "./lib/telemetry/helpers/jsonifier"

module Telemetry
  class Annotation
    include Helpers::TimeMaker
    include Helpers::Jsonifier

    attr_reader :params, :log_time

    def initialize(params={})
      @params = params
      @log_time = time
    end

    def to_hash
      params.merge({:time => log_time})
    end
  end
end
