require "spec_helper"
require "telemetry/tracer"

module Telemetry
  class Tracer
    #reset the tracer for testing purposes
    class << self
      def reset_with_config
        Tracer.instance_variable_set("@tracer", nil)
        Tracer.instance_variable_set("@config", nil)
      end
    end
  end

  describe Tracer do

    after do
      Tracer.reset_with_config
    end

    it "creates a trace if one does not already exist" do
      tracer1 = Tracer.find_or_create
      tracer2 = Tracer.find_or_create
      expect(tracer1).to eq(tracer2)
    end

    it "returns the currently existing trace" do
      Tracer.reset_with_config
      tracer = Tracer.current
      expect(tracer).to be_nil

      tracer = Tracer.find_or_create
      expect(tracer.class).to eq(Tracer)
    end

    it "initializes itself with a trace id if one is passed" do
      trace_id = "abc123"
      tracer = default_tracer({"trace_id" => trace_id, "parent_span_id" => "fubar"})
      expect(tracer.id).to eq(trace_id)
    end

    it "generates a 64bit id for itself if a trace_id is not supplied" do
      tracer = default_tracer
      expect(tracer.id.size).to eq(8)
    end

    it "markes itself as dirty and gives a reason if either trace_id is present but parent span id isn't" do
      tracer = default_tracer({"trace_id" => "fubar123"})
      expect(tracer.dirty?).to be_true
      expect(tracer.to_hash[:tainted]).to eq("trace_id present; parent_span_id not present.")
    end

    it "markes itself as dirty if trace id is not present but parent_span_id is" do
      tracer = default_tracer({"enabled" => true, "parent_span_id" => "fubar123"})
      expect(tracer.dirty?).to be_true
      expect(tracer.to_hash[:tainted]).to eq("trace_id not present; parent_span_id present. Auto generating trace id")
    end

    it "comes with a brand new span out of the box" do
      tracer = default_tracer
      expect(tracer.spans.size).to eq(1)
      expect(tracer.spans.first.class).to eq(Span)
    end

    it "passes any annotations to the current span" do
      tracer = default_tracer
      expect(tracer.current_span.annotations.empty?).to be_true

      tracer.annotate("UserAgent", "Firefox")
      expect(tracer.current_span.annotations.size).to eq(1)
    end

    it "only does initializations if its allowed to run" do
      tracer = default_tracer({"enabled" => false, "trace_id" => "123", "parent_span_id" => "234"})
      expect(tracer.spans).to be_nil
      expect(tracer.id).to be_nil
      expect(tracer.current_span).to be_nil
    end

    it "accepts an override flag which it passes to the runner object" do
      tracer = default_tracer
      expect(tracer.run?).to be_true

      tracer.override = false
      expect(tracer.run?).to be_false
    end

    it "runs the start method of a trace only if its allowed to run" do
      tracer = default_tracer({"enabled" => false})
      expect(tracer.in_progress?).to be_false

      tracer.start
      expect(tracer.in_progress?).to be_false
    end

    it "runs the stop method of a trace only if its allowed to run" do
      tracer = default_tracer({:enabled => false})
      expect(tracer.in_progress?).to be_false

      tracer.stop
      expect(tracer.in_progress?).to be_false
    end

    it "turns off the progress sign after its been stopped" do
      tracer = default_tracer
      expect(tracer.in_progress?).to be_false

      tracer.start
      expect(tracer.in_progress?).to be_true

      tracer.stop
      expect(tracer.in_progress?).to be_false
    end

    it "applying a trace around a block logs the start and end times for the current span" do
      tracer = default_tracer
      tracer.apply do
        expect(tracer.current_span.start_time.nil?).to be_false
        2*2
      end
      expect(tracer.current_span.stop_time.nil?).to be_false
    end

    it "applying a trace yields the trace so annotations can be added to it" do
      tracer = default_tracer
      tracer.apply do |trace|
        expect(tracer.annotations).to be_empty

        trace.annotate("foo", "bar")
        expect(tracer.annotations.size).to eq(1)
      end
    end

    it "can be started only if its allowed to run" do
      tracer = default_tracer({"enabled" => false})
      expect(tracer.run?).to be_false

      tracer.start
      expect(tracer.in_progress?).to be_false
    end

    it "can be applied only if its allowed to run" do
      tracer = default_tracer({"enabled" => false})
      expect(tracer.run?).to be_false

      tracer.apply do |trace|
        expect(tracer.in_progress?).to be_false
      end
    end

    it "sets the flushed state to true once its flushed" do
      tracer = default_tracer
      expect(tracer.flushed?).to be_false

      tracer.stop
      expect(tracer.flushed?).to be_true
    end

    it "starting a new span makes the current span the parent span" do
      tracer = default_tracer
      previous_span = tracer.current_span
      new_span = tracer.start_new_span("fubar2")
      expect(new_span.name).to eq("fubar2")
      expect(new_span.id).not_to eq(previous_span.id)
      expect(new_span.parent_span_id).to eq(previous_span.id)
      expect(new_span.tracer.id).to eq(previous_span.tracer.id)
    end

    it "assigns a name to the created span if one is given" do
      tracer = default_tracer({"name" => "fubar2"})
      expect(tracer.current_span.name).to eq("fubar2")
    end

    it "passes blocks to be post processed to the current span" do
      restart_celluloid
      tracer = default_tracer
      tracer.post_process("foo") do
        x = 2
        10.times { x = x*2 }
        x
      end

      expect(tracer.current_span.post_process_blocks["foo"].class).to eq(Celluloid::Future)
    end

    it "executes any post process blocks associated with the current span when its stopped" do
      restart_celluloid
      tracer = default_tracer
      tracer.start
      tracer.post_process("foo") do
        x = 2
        10.times { x = x*2 }
        x
      end
      tracer.stop
      processed_annotations = tracer.to_hash[:spans].first[:annotations]
      expect(processed_annotations.size).to eq(1)
      expect(processed_annotations.first["foo"]).to eq(2048)
    end

    it "terminates the trace once its stopped" do
      tracer = default_tracer
      tracer.apply do
        expect(Telemetry::Tracer.current).not_to be_nil
        2*2
      end
      expect(Telemetry::Tracer.current).to be_nil
    end

    it "stops all spans attached to the trace that's stopped" do
      tracer = default_tracer
      tracer.start
      expect(tracer.spans.size).to eq(1)

      tracer.start_new_span("newspan")
      expect(tracer.spans.size).to eq(2)

      tracer.stop
      expect(tracer.spans.size).to eq(2)

      tracer.to_hash[:spans].each do |span|
        expect(span[:stop_time]).not_to be_nil
      end
    end

    it "cannot restart a stale trace" do
      tracer = default_tracer
      tracer.apply { 2*2 }
      expect{tracer.start}.to raise_error(TraceFlushedException)
    end

    it "cannot stop a stale trace" do
      tracer = default_tracer
      tracer.apply { 2*2 }
      expect{tracer.stop}.to raise_error(TraceFlushedException)
    end

    it "bumps the current span if the current span has been processed" do
      tracer = default_tracer
      span0 = tracer.current_span
      span1 = tracer.start_new_span("foobar")
      expect(tracer.current_span).to eq(span1)

      span1.stop
      expect(tracer.current_span).to eq(span0)
    end
  end
end
