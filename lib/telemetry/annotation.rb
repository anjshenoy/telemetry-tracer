require "telemetry/helper"

module Telemetry
  class Annotation
    include Helpers::TimeMaker
    include Helpers::Jsonifier

    attr_reader :params, :log_time, :time_to_process

    def initialize(params={}, time_to_process=nil)
      @params = params
      @log_time = time
      if !time_to_process.nil?
        @time_to_process = time_to_process
      end
    end

    def to_hash
      hash = params.merge({:logged_at => log_time.to_s})
      if !time_to_process.nil?
        hash.merge!({:time_to_process => time_to_process.to_s})
      end
      hash
    end
  end
end
