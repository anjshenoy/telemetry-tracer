require "spec_helper"
require "telemetry/instrumentation/zephyr"
require "telemetry/tracer"
require "telemetry/helpers/timer"
require "telemetry/sinks/sink"

class TestException < Exception; end
class Zephyr

  attr_reader :time_of_request
  include Telemetry::Helpers::Timer

  #fake perform method to return headers
  def perform_without_trace(method, path_components, headers, expect, timeout, data=nil)
    @time_of_request = time

    #magic happens on this line

    {"X-Telemetry-TraceId" => headers["X-Telemetry-TraceId"],
     "X-Telemetry-SpanId"  => headers["X-Telemetry-SpanId"]}
  end
end

module Telemetry

  #mock the calls to zephyr perform
  class Client
    attr_reader :zep

    def initialize(trace_id, parent_span_id)
      @headers = {"X-Telemetry-TraceId" => trace_id,
                  "X-Telemetry-SpanId" => parent_span_id,
                  "Content-type" => "application/json"}
      @zep = Zephyr.new
    end

    def get_nice
      @zep.get(200, 100, ["users"], @headers)
    end

    def get_with_exception
      @zep.get(200, 1000, ["users"], @headers)
      raise TestException.new("test message")
    end
  end

  describe Client do
    Telemetry::Tracer.config = in_memory_tracer_opts
    after do
      Telemetry::Sinks::InMemorySink.flush!
    end

    let(:dummy) { Client.new }

    it "contructs a new span from the parent span around the perform method where the parent span specs arrive in the headers" do
      trace = Telemetry::Tracer.fetch
      trace.apply do; end

      #starts a new span
      client = Client.new(trace.id, trace.to_hash[:current_span_id])
      client.get_nice
      traces = Telemetry::Sinks::InMemorySink.traces
      expect(traces.size).to eq(2)
      expect(traces.first).to eq(trace.to_hash)

      expect(traces.last[:spans].first[:parent_span_id]).to eq(trace.to_hash[:spans].first[:id])
    end

    it "constructs a new trace/span if there is is no trace information in the headers" do
      client = Client.new(nil, nil)
      client.get_nice
      expect(Telemetry::Sinks::InMemorySink.traces.size).to eq(1)
    end

    it "sends the trace id and the span id as headers along with the request" do
      client = Client.new(nil, nil)
      headers = client.get_nice
      trace = Telemetry::Sinks::InMemorySink.traces.first
      trace_id = trace[:id]
      span_id = trace[:spans].first[:id]

      expect(headers["X-Telemetry-TraceId"]).to eq(trace_id)
      expect(headers["X-Telemetry-SpanId"]).to eq(span_id)
    end

    it "logs UserAgent and ClientSent annotations before the request is sent" do
      client = Client.new(nil, nil)
      client.get_nice
      trace = Telemetry::Sinks::InMemorySink.traces.first
      annotations = trace[:spans].first[:annotations]
      useragent_annotation_time = annotations[0][:logged_at]
      clientsent_annotation_time = annotations[1][:logged_at]

      time_of_request = client.zep.time_of_request

      expect(useragent_annotation_time).to be < time_of_request
      expect(clientsent_annotation_time).to be < time_of_request
    end

    it "logs the Client Received annotation when it receives a response" do
      client = Client.new(nil, nil)
      client.get_nice
      trace = Telemetry::Sinks::InMemorySink.traces.first
      annotations = trace[:spans].first[:annotations]
      clientreceived_annotation_time = annotations.last[:logged_at]

      time_of_request = client.zep.time_of_request

      expect(clientreceived_annotation_time).to be > time_of_request
    end

    it "logs the Client Exception annotation if there is an exception" do
      client = Client.new(nil, nil)
      begin
        client.get_with_exception
      rescue TestException
        trace = Telemetry::Sinks::InMemorySink.traces.first
        client_exception_annotation = trace[:spans].first[:annotations][2]
        client_exception_annotation_time = client_exception_annotation[:logged_at]
        expect(client_exception_annotation_time).not_to be_nil
      end
    end

    it "logs the Client Received annotation even if there is an exception" do
      client = Client.new(nil, nil)
      begin
        client.get_with_exception
      rescue TestException
      end
      trace = Telemetry::Sinks::InMemorySink.traces.first

      annotations = trace[:spans].first[:annotations]
      clientreceived_annotation_time = annotations.last[:logged_at]
      expect(clientreceived_annotation_time).not_to be_nil
    end

    it "has no side effects if switched off" do
      Telemetry::Tracer.override = false
      client = Client.new(nil, nil)
      client.get_nice

      expect(Telemetry::Sinks::InMemorySink.traces).to be_empty
    end

  end
end
