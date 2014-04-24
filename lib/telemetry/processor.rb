require "celluloid"
require "telemetry/helpers/timer"

module Telemetry
  class Processor
    include Helpers::Timer

    attr_reader :name, :future, :ignore_if_blank

    def initialize(name, ignore_if_blank = false, &block)
      @name = name
      @ignore_if_blank = ignore_if_blank
      @future = Celluloid::Future.new(&block)
      @value = nil
      @exception = nil
    end

    def run
      instrument do
        begin
          @value = future.value
        rescue Exception => ex
          @value = "processing_error"
          @exception = ex.class.to_s + ": " + ex.message + "\n" + ex.backtrace.join("\n")
        end
      end

      if ignore_if_blank
        return (@value.nil? || @value == "") ? nil : to_hash
      end

      return to_hash
    end

    def to_hash
      hash = {@name => @value, 
              :instrumentation_time => @instrumentation_time }
      @exception.nil? ? hash : hash.merge({:exception => @exception})
    end

  end
end
