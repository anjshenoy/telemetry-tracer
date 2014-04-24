require "spec_helper"
require "telemetry/sinks/sink"

module Telemetry
  class MockTrace

    def initialize(id, span_id)
      @id = id
      @current_span_id = span_id
    end

    def to_hash
      {:id => @id, :current_span_id => @current_span_id}
    end

  end

  module Sinks
    describe Sink do
      let(:error_logger) { ::Logger.new("/tmp/tracer_errors.log") }

      it "raises an exception if neither the log file nor a http end point is supplied" do
        expect{Sink.new(nil, nil, error_logger)}.to raise_exception(MissingSinkDeviceException)

        expect{Sink.new(nil, {}, error_logger)}.to raise_exception(MissingSinkDeviceException)
      end

      it "raises an exception if no error log device is supplied" do
        expect{Sink.new("/tmp/tracer.log", nil, nil)}.to raise_exception(ErrorLogDeviceNotFound)
      end

      it "creates an in memory sink if an option is provided" do
        sink = Sink.new(nil, nil, error_logger, true)
        expect(sink.traces).to eq([])
      end

      it "aggregates trace outputs in memory" do
        trace = Telemetry::MockTrace.new(123456789, 5678)
        sink = Sink.new(nil, nil, error_logger, true)
        sink.process(trace)

        expect(Telemetry::Sinks::InMemorySink.traces.size).to eq(1)
        expect(Telemetry::Sinks::InMemorySink.traces.first).to eq({:id => 123456789, 
                                                 :current_span_id => 5678})

        trace2 = Telemetry::MockTrace.new(12345678900, 567800)
        sink.process(trace2)

        expect(Telemetry::Sinks::InMemorySink.traces.size).to eq(2)
        expect(Telemetry::Sinks::InMemorySink.traces.last).to eq({:id => 12345678900, 
                                                :current_span_id => 567800})
      end

    end
  end
end
