require "./lib/telemetry/helpers/time_maker"

module Telemetry
  class Annotation
    include Helpers::TimeMaker

    attr_reader :params, :start_time

    def initialize(params={})
      @params = params
      @start_time = time
    end
  end
end
