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

    before do
      Tracer.reset_with_config
    end

    it "can set the config separately" do
      Tracer.config = {}
      expect(Tracer.config.runner.enabled?).to be_false
    end

    it "sets the config once during its lifetime" do
      Tracer.config = tracer_opts
      expect(Tracer.config.runner.run?).to be_true

      Tracer.config = {:enabled => false}
      expect(Tracer.config.runner.run?).to be_true
    end

    it "accepts an override flag which enables or disables all running instances" do
      Tracer.config = tracer_opts
      expect(Tracer.override?).to be_true

      tracer = Tracer.find_or_create
      expect(tracer.run?).to be_true

      Tracer.override = false
      expect(Tracer.override?).to be_false
      expect(tracer.run?).to be_false
    end

    it "has a with_override api which applies the override flag to all running instances" do
      Tracer.config = tracer_opts
      expect(Tracer.override?).to be_true

      expect(Tracer.with_override(false).override?).to be_false
    end

    it "has a with_config api which applies the supplied config opts and returns self" do
      expect(Tracer.with_config(tracer_opts).override?).to be_true
    end

    it "preinitializes itself with a default config if not set up with one when find_or_create is called" do
      Tracer.find_or_create
      expect(Tracer.config.run?).to be_false
    end

    it "does not reinitialize itself with a new config if one is already set when find_or_create is called" do
      expect(Tracer.with_config(tracer_opts).find_or_create.config.run?).to be_true
    end

    it "creates a trace if one does not already exist" do
      tracer1 = Tracer.find_or_create
      tracer2 = Tracer.find_or_create
      expect(tracer1).to eq(tracer2)
    end

    it "returns the currently existing trace" do
      tracer = Tracer.current
      expect(tracer).to be_nil

      tracer = Tracer.find_or_create
      expect(tracer.class).to eq(Tracer)
    end

    it "initializes itself with a trace id if one is passed" do
      trace_id = "abc123"
      tracer = Tracer.with_config(tracer_opts).find_or_create({"trace_id" => trace_id, "parent_span_id" => "fubar"})
      expect(tracer.id).to eq(trace_id)
    end

    it "generates a 64bit id for itself if a trace_id is not supplied" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      expect(tracer.id.size).to eq(8)
    end

    it "markes itself as dirty and gives a reason if either trace_id is present but parent span id isn't" do
      tracer = Tracer.with_config(tracer_opts).find_or_create({"trace_id" => "fubar123"})
      expect(tracer.dirty?).to be_true
      expect(tracer.to_hash[:tainted]).to eq("trace_id present; parent_span_id not present.")
    end

    it "markes itself as dirty if trace id is not present but parent_span_id is" do
      tracer = Tracer.with_config(tracer_opts).find_or_create({"enabled" => true, "parent_span_id" => "fubar123"})
      expect(tracer.dirty?).to be_true
      expect(tracer.to_hash[:tainted]).to eq("trace_id not present; parent_span_id present. Auto generating trace id")
    end

    it "comes with a brand new span out of the box" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      expect(tracer.spans.size).to eq(1)
      expect(tracer.spans.first.class).to eq(Span)
    end

    it "sets up the current span with a parent span id if one is supplied" do
      tracer = Tracer.with_config(tracer_opts).find_or_create({"trace_id" => 123456789, "parent_span_id" => 456789})
      expect(tracer.current_span.parent_span_id).to eq(456789)
      expect(tracer.spans.size).to eq(1)
    end

    it "passes any annotations to the current span" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      expect(tracer.current_span.annotations.empty?).to be_true

      tracer.annotate("UserAgent", "Firefox")
      expect(tracer.current_span.annotations.size).to eq(1)
    end

    it "only does initializations if its allowed to run" do
      Tracer.config = tracer_opts.merge("enabled" => false)
      tracer = Tracer.find_or_create({"trace_id" => "123", "parent_span_id" => "234"})
      expect(tracer.spans).to be_nil
      expect(tracer.id).to be_nil
      expect(tracer.current_span).to be_nil
    end

    it "runs the start method of a trace only if its allowed to run" do
      Tracer.config = tracer_opts.merge({"enabled" => false})
      tracer = Tracer.find_or_create
      expect(tracer.in_progress?).to be_false

      tracer.start
      expect(tracer.in_progress?).to be_false
    end

    it "runs the stop method of a trace only if its allowed to run" do
      Tracer.config = tracer_opts.merge({"enabled" => false})
      tracer = Tracer.find_or_create
      expect(tracer.in_progress?).to be_false

      tracer.stop
      expect(tracer.in_progress?).to be_false
    end

    it "turns off the progress sign after its been stopped" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      expect(tracer.in_progress?).to be_false

      tracer.start
      expect(tracer.in_progress?).to be_true

      tracer.stop
      expect(tracer.in_progress?).to be_false
    end

    it "applying a trace around a block logs the start time and duration for the current span" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.apply do
        expect(tracer.current_span.start_time.nil?).to be_false
        2*2
      end
      expect(tracer.current_span.duration.nil?).to be_false
    end

    it "applying a trace yields the trace so annotations can be added to it" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.apply do |trace|
        expect(tracer.annotations).to be_empty

        trace.annotate("foo", "bar")
        expect(tracer.annotations.size).to eq(1)
      end
    end

    it "can be started only if its allowed to run" do
      Tracer.config = tracer_opts.merge({"enabled" => false})
      tracer = Tracer.find_or_create
      expect(tracer.run?).to be_false

      tracer.start
      expect(tracer.in_progress?).to be_false
    end

    it "can be applied only if its allowed to run" do
      Tracer.config = tracer_opts.merge({"enabled" => false})
      tracer = Tracer.find_or_create
      expect(tracer.run?).to be_false

      tracer.apply do |trace|
        expect(tracer.in_progress?).to be_false
      end
    end

    it "yields itself and the current_span if applied" do
      Tracer.with_config(tracer_opts).find_or_create.apply do |tracer, span|
        expect(tracer).not_to be_nil
        expect(span).not_to be_nil
        expect(tracer.current_span).to eq(span)
      end
    end

    it "sets the flushed state to true once its flushed" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      expect(tracer.flushed?).to be_false

      tracer.stop
      expect(tracer.flushed?).to be_true
    end

    it "starting a new span makes the current span the parent span" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      previous_span = tracer.current_span
      new_span = tracer.start_new_span("fubar2")
      expect(new_span.name).to eq("fubar2")
      expect(new_span.id).not_to eq(previous_span.id)
      expect(new_span.parent_span_id).to eq(previous_span.id)
      expect(new_span.tracer.id).to eq(previous_span.tracer.id)
    end

    it "starting a new span automatically logs the start time of that span" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      new_span = tracer.start_new_span("fubar2")
      expect(new_span.start_time).not_to be_nil
    end

    it "assigns a name to the created span if one is given" do
      tracer = Tracer.with_config(tracer_opts).find_or_create({"name" => "fubar2"})
      expect(tracer.current_span.name).to eq("fubar2")
    end

    it "passes blocks to be post processed to the current span" do
      restart_celluloid
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.post_process("foo") do
        x = 2
        10.times { x = x*2 }
        x
      end

      expect(tracer.current_span.post_process_blocks["foo"].class).to eq(Celluloid::Future)
    end

    it "executes any post process blocks associated with the current span when its stopped" do
      restart_celluloid
      tracer = Tracer.with_config(tracer_opts).find_or_create
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
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.apply do
        expect(Telemetry::Tracer.current).not_to be_nil
        2*2
      end
      expect(Telemetry::Tracer.current).to be_nil
    end

    it "stops all spans attached to the trace that's stopped" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.start
      expect(tracer.spans.size).to eq(1)

      tracer.start_new_span("newspan")
      expect(tracer.spans.size).to eq(2)

      tracer.stop
      expect(tracer.spans.size).to eq(2)

      tracer.to_hash[:spans].each do |span|
        expect(span[:duration]).not_to be_nil
      end
    end

    it "cannot restart a stale trace" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.apply { 2*2 }
      expect{tracer.start}.to raise_error(TraceFlushedException)
    end

    it "cannot stop a stale trace" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.apply { 2*2 }
      expect{tracer.stop}.to raise_error(TraceFlushedException)
    end

    it "bumps the current span if the current span has been processed" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      span0 = tracer.current_span
      span1 = tracer.start_new_span("foobar")
      expect(tracer.current_span).to eq(span1)

      span1.stop
      expect(tracer.current_span).to eq(span0)
    end

    it "logs the instrumnentation time only if allowed to run" do
      Tracer.config = tracer_opts.merge({"enabled" => false})
      tracer = Tracer.find_or_create
      tracer.apply { 2*2 }
      expect(tracer.to_hash.has_key?(:time_to_instrument_trace_bits_only)).to be_false
    end

    it "logs the instrumnentation time when stopped and if allowed to run" do
      Tracer.config = tracer_opts.merge({:enabled => false})
      tracer = Tracer.find_or_create

      tracer.apply { 2*2 }
      expect(tracer.to_hash[:time_to_instrument_trace_bits_only]).not_to be_nil
    end

    it "stops a span only if its in progress" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.start
      tracer.apply_new_span do
        2*2
      end

      expect(tracer.spans.last.stopped?).to be_true
      expect(tracer.spans.first.stopped?).to be_false

      tracer.stop
      expect(tracer.spans.first.stopped?).to be_true
    end

    it "can apply a new span around a given block of code" do
      tracer = Tracer.with_config(tracer_opts).find_or_create

      current_span = tracer.current_span
      tracer.apply_new_span do |span|
        expect(tracer.current_span).to eq(span)
        expect(tracer.current_span).not_to eq(current_span)
        expect(span.in_progress?).to be_true
      end
      expect(tracer.spans.size).to eq(2)
    end

    it "can apply a new span with an optional name parameter" do
      tracer = Tracer.with_config(tracer_opts).find_or_create

      tracer.apply_new_span("foo") do |span|
        expect(span.name).to eq("foo")
      end
    end

    it "takes an optional span_name when applied around a block" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.apply("foo") do |trace|
        expect(trace.current_span.name).to eq("foo")
      end
    end

    it "takes an optional span name when started" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.start("foo")
      expect(tracer.current_span.name).to eq("foo")
    end

    it "resets the current trace if the override state is switched" do
      Tracer.config = tracer_opts

      tracer1 = Tracer.with_override(false).fetch
      expect(tracer1.annotations).to be_nil

      tracer2 = Tracer.with_override(true).fetch
      expect(tracer1).not_to eq(tracer2)
      expect(tracer2.annotations).to be_empty

      tracer3 = Tracer.with_override(false).fetch
      expect(tracer1).not_to eq(tracer3)
      expect(tracer2).not_to eq(tracer3)
      expect(tracer3.annotations).to be_nil
    end

    it "returns annotations for the current_span only if its allowed to run" do
      Tracer.config = tracer_opts

      tracer = Tracer.with_override(false).fetch
      expect(tracer.run?).to be_false
      expect(tracer.annotations).to be_nil

      tracer = Tracer.with_override(true).fetch
      expect(tracer.annotations).to be_empty
    end

    it "annotates the current span only if its allowed to run" do
      Tracer.config = tracer_opts

      tracer = Tracer.with_override(false).fetch
      expect(tracer.run?).to be_false
      tracer.annotate("key", "value")
      expect(tracer.annotations).to be_nil

      tracer = Tracer.with_override(true).fetch
      expect(tracer.run?).to be_true
      tracer.annotate("key", "value")
      expect(tracer.annotations).not_to be_empty
      expect(tracer.annotations.size).to eq(1)
    end

    it "returns post process blocks for the current span only if its allowed to run" do
      Tracer.config = tracer_opts

      tracer = Tracer.with_override(false).fetch
      expect(tracer.run?).to be_false
      expect(tracer.post_process_blocks).to be_nil

      tracer = Tracer.with_override(true).fetch
      expect(tracer.post_process_blocks).to be_empty
    end

    it "stores a proc for post process only if its allowed to run" do
      Tracer.config = tracer_opts

      tracer = Tracer.with_override(false).fetch
      expect(tracer.run?).to be_false
      tracer.post_process("key") do
        2*2
      end
      expect(tracer.post_process_blocks).to be_nil


      tracer = Tracer.with_override(true).fetch
      expect(tracer.run?).to be_true
      tracer.post_process("key") do
        2*2
      end
      expect(tracer.post_process_blocks).not_to be_empty
      expect(tracer.post_process_blocks.size).to eq(1)
    end

    it "anything that's not whitelisted for the current span results in a NoMethodError" do
      tracer = Tracer.with_config(tracer_opts).with_override(true).fetch
      expect{tracer.foo}.to raise_error(NoMethodError)
    end
  end
end
