require "spec_helper"
require "telemetry/sinks/sink"

module Telemetry
  module Sinks
    describe Sink do
      it "raises an exception if neither the log file nor a http end point is supplied" do
        error_logger = ::Logger.new("/tmp/tracer_errors.log")
        expect{Sink.new(nil, nil, error_logger)}.to raise_exception(MissingSinkDeviceException)

        expect{Sink.new(nil, {}, error_logger)}.to raise_exception(MissingSinkDeviceException)
      end

      it "raises an exception if no error log device is supplied" do
        expect{Sink.new("/tmp/tracer.log", nil, nil)}.to raise_exception(ErrorLogDeviceNotFound)
      end
    end
  end
end
