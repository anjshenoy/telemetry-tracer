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

    {Telemetry::TRACE_HEADER_KEY => headers[Telemetry::TRACE_HEADER_KEY],
     Telemetry::SPAN_HEADER_KEY  => headers[Telemetry::SPAN_HEADER_KEY]}
  end
end

module Telemetry

  #mock the calls to zephyr perform
  class Client
    attr_reader :zep

    def initialize(trace_id, parent_span_id)
      @headers = {Telemetry::TRACE_HEADER_KEY => trace_id,
                  Telemetry::SPAN_HEADER_KEY => parent_span_id,
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
    before do
      Tracer.reset_with_config
      Telemetry::Tracer.config = in_memory_tracer_opts
      Telemetry::Sinks::InMemorySink.flush!
    end

    let(:dummy) { Client.new }

    it "contructs a new span from the parent span around the perform method where the parent span specs arrive in the headers" do
      trace = Telemetry::Tracer.fetch
      trace.apply do; end
      first_span = trace.spans.first

      #assume this comes from a worker 
      #so the parent span is actually done by the time it gets here
      #and a new span with the original parent span ID is constructed
      client = Client.new(trace.id, trace.current_span_id)
      client.get_nice
      spans = Telemetry::Sinks::InMemorySink.traces
      expect(spans.size).to eq(2)
      expect(spans.first).to eq(first_span)

      expect(spans.last[:parent_span_id]).to eq(first_span[:span_id])
    end

    it "constructs a new trace/span if there is is no trace information in the headers" do
      client = Client.new(nil, nil)
      client.get_nice
      expect(Telemetry::Sinks::InMemorySink.traces.size).to eq(1)
    end

    it "sends the trace id and the span id as headers along with the request" do
      client = Client.new(nil, nil)
      headers = client.get_nice
      first_span = Telemetry::Sinks::InMemorySink.traces.first

      expect(headers["X-Telemetry-TraceId"]).to eq(first_span[:trace_id])
      expect(headers["X-Telemetry-SpanId"]).to eq(first_span[:span_id])
    end

    it "logs UserAgent and ClientSent annotations before the request is sent" do
      client = Client.new(nil, nil)
      client.get_nice
      span = Telemetry::Sinks::InMemorySink.traces.first
      annotations = span[:annotations]
      useragent_annotation_time = annotations[0][:logged_at]
      clientsent_annotation_time = annotations[1][:logged_at]

      time_of_request = client.zep.time_of_request

      expect(useragent_annotation_time).to be < time_of_request
      expect(clientsent_annotation_time).to be < time_of_request
    end

    it "logs the Client Received annotation when it receives a response" do
      client = Client.new(nil, nil)
      client.get_nice
      span = Telemetry::Sinks::InMemorySink.traces.first
      annotations = span[:annotations]
      clientreceived_annotation_time = annotations.last[:logged_at]

      time_of_request = client.zep.time_of_request

      expect(clientreceived_annotation_time).to be > time_of_request
    end

    it "logs the Client Exception annotation if there is an exception" do
      client = Client.new(nil, nil)
      begin
        client.get_with_exception
      rescue TestException
        span = Telemetry::Sinks::InMemorySink.traces.first
        client_exception_annotation = span[:annotations][2]
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
      span = Telemetry::Sinks::InMemorySink.traces.first

      annotations = span[:annotations]
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
