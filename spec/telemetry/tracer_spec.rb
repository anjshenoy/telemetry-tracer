require "spec_helper"
require "telemetry/tracer"

module Telemetry
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

    it "raises a ConfigNotApplied exception if with_override is called before the config is applied" do
      expect{Tracer.with_override(true)}.to raise_error(ConfigNotApplied)
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
      Tracer.config = tracer_opts
      tracer = Tracer.fetch
      expect(tracer.enabled?).to be_true

      Tracer.config = tracer_opts.merge({"enabled" => false})
      tracer2 = Tracer.fetch
      expect(tracer2.enabled?).to be_true
    end

    it "creates a trace if one does not already exist" do
      tracer1 = Tracer.find_or_create
      tracer2 = Tracer.find_or_create
      expect(tracer1).to eq(tracer2)
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
      expect(tracer.to_hash[:tainted]).to eq("trace_id present; parent_span_id not present.")
    end

    it "markes itself as dirty if trace id is not present but parent_span_id is" do
      tracer = Tracer.with_config(tracer_opts).find_or_create({"enabled" => true, "parent_span_id" => "fubar123"})
      expect(tracer.to_hash[:tainted]).to eq("trace_id not present; parent_span_id present. Auto generating trace id")
    end

    it "comes with a brand new span out of the box" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      expect(tracer.to_hash[:spans].size).to eq(1)
    end

    it "sets up the current span with a parent span id if one is supplied" do
      tracer_hash = Tracer.with_config(tracer_opts).find_or_create({"trace_id" => 123456789, 
                                                               "parent_span_id" => 456789}).to_hash
      expect(tracer_hash[:spans].size).to eq(1)
      expect(tracer_hash[:spans].first[:parent_span_id]).to eq(456789)
      expect(tracer_hash[:spans].first[:id]).to eq(tracer_hash[:current_span_id])
    end

    it "passes any annotations to the current span" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      aggregated_annotations = tracer.to_hash[:spans].map{|span| span[:annotations]}.flatten
      expect(aggregated_annotations).to be_empty

      tracer.annotate("UserAgent", "Firefox")
      current_span = tracer.to_hash[:spans].first
      span_annotations = current_span[:annotations]

      expected_hash = {"UserAgent" => "Firefox"}
      expect(span_annotations.first).to include(expected_hash)
    end

    it "only does initializations if its allowed to run" do
      Tracer.config = tracer_opts.merge("enabled" => false)
      expect(Tracer.run?).to be_false

      tracer = Tracer.find_or_create({"trace_id" => "123", "parent_span_id" => "234"})
      expect(tracer.id).to be_nil
      expect(tracer.to_hash).to be_empty
    end

    it "is in progress only once its started and before its stopped" do
      tracer = Tracer.with_config(tracer_opts).find_or_create

      expect(tracer.in_progress?).to be_false
      tracer.apply do |trace|
        expect(tracer.in_progress?).to be_true
      end
      expect(tracer.in_progress?).to be_false
    end

    it "still finishes processing if the override flag is switched off after a trace starts but before it stops" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      expect(tracer.enabled?).to be_true

      aggregated_annotations = tracer.to_hash[:spans].map{|span| span[:annotations]}.flatten
      expect(aggregated_annotations).to be_empty

      tracer.apply do |trace|
        trace.post_process("foo") do
          2*2
        end
        Tracer.override = false
        expect(tracer.enabled?).to be_true
      end

      expected_hash = {"foo" => 4}
      aggregated_annotations = tracer.to_hash[:spans].map{|span| span[:annotations]}.flatten
      expect(aggregated_annotations.size).to eq(1)
      expect(aggregated_annotations.first).to include(expected_hash)
    end

    it "returns the currently executing trace even if the override flag is switched off" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      expect(Tracer.override?).to be_true

      tracer.apply do |trace|
        expect(Tracer.fetch).to eq(tracer)

        Tracer.override = false
        expect(Tracer.override?).to be_false
        expect(Tracer.fetch).to eq(tracer)
      end
    end

    it "resets the current trace if it isnt in progress if the override flag is switched off" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      expect(Tracer.override?).to be_true
      expect(Tracer.fetch).to eq(tracer)
      expect(tracer.in_progress?).to be_false

      Tracer.override = false
      expect(Tracer.override?).to be_false
      expect(Tracer.fetch).not_to eq(tracer)
    end

    it "resets the current trace and returns a new one each time the override state is switched" do
      Tracer.config = tracer_opts

      tracer1 = Tracer.with_override(false).fetch
      expect(tracer1.enabled?).to be_false

      tracer2 = Tracer.with_override(true).fetch
      expect(tracer1).not_to eq(tracer2)
      expect(tracer2.enabled?).to be_true

      tracer3 = Tracer.with_override(false).fetch
      expect(tracer1).not_to eq(tracer3)
      expect(tracer2).not_to eq(tracer3)
      expect(tracer3.enabled?).to be_false
    end

    it "returns the current trace at any point in time" do
      Tracer.config = tracer_opts

      tracer1 = Tracer.fetch
      expect(Tracer.fetch).to eq(tracer1)
      tracer1.apply do; end

      #automaticallly fetches a new trace now that the first one is done
      expect(Tracer.fetch).not_to eq(tracer1)
    end

    it "applying a trace around a block logs the start time and duration for the current span" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.apply do
        expect(tracer.to_hash[:spans].first[:start_time]).to be > 0
        2*2
      end
      expect(tracer.to_hash[:spans].first[:duration]).to be > 0
    end

    it "applying a trace around a block yields the trace so annotations can be added to it" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.apply do |trace|
        aggregated_annotations = tracer.to_hash[:spans].map{|span| span[:annotations]}.flatten
        expect(aggregated_annotations).to be_empty

        trace.annotate("foo", "bar")
        aggregated_annotations = tracer.to_hash[:spans].map{|span| span[:annotations]}.flatten
        expect(aggregated_annotations.size).to eq(1)
      end
    end

    it "can be applied only if its allowed to run" do
      Tracer.config = tracer_opts.merge({"enabled" => false})
      tracer = Tracer.find_or_create
      expect(tracer.enabled?).to be_false

      tracer.apply do |trace|
        expect(trace.in_progress?).to be_false
      end
    end

    it "allows the program to go through the normal flow of execution if its switched off" do
      Tracer.config = tracer_opts.merge({"enabled" => false})
      tracer = Tracer.find_or_create

      x = 0
      tracer.apply do |trace|
        x = 2*2
      end

      expect(x).to eq(4)
    end

    it "yields itself if applied" do
      Tracer.with_config(tracer_opts).find_or_create.apply do |tracer|
        expect(tracer.is_a?(Tracer)).to be_true
      end
    end

    it "can be applied with an annotation" do
      Tracer.with_config(tracer_opts).fetch.apply_with_annotation("span1", "key", "value") do |tracer|
        expect(tracer.is_a?(Tracer)).to be_true
        current_span = tracer.to_hash[:spans].first
        expect(current_span[:name]).to eq("span1")
        expect(current_span[:annotations].first.to_hash).to include({"key" => "value"})
      end
    end

    it "can be applied wtih multiple annotations" do
      annotations = [["UserAgent", "Zephyr"], ["ClientSent", ""]]
      Tracer.with_config(tracer_opts).fetch.apply_with_annotations("span1", annotations) do |tracer|
        expect(tracer.is_a?(Tracer)).to be_true
        current_span = tracer.to_hash[:spans].first

        expect(current_span[:name]).to eq("span1")
        expect(current_span[:annotations].first.to_hash).to include({"UserAgent" => "Zephyr"})
        expect(current_span[:annotations].last.to_hash).to include({"ClientSent" => ""})
      end
    end

    it "applying a new span makes the current span the parent span" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      previous_span_id = tracer.to_hash[:current_span_id]
      tracer.apply do |trace|
        trace.apply_new_span("fubar2") do |inner_trace|
          new_span = tracer.to_hash[:spans].last
          expect(new_span[:name]).to eq("fubar2")
          expect(new_span[:id]).not_to eq(previous_span_id)
          expect(new_span[:parent_span_id]).to eq(previous_span_id)
        end
      end
    end

    it "starting a new span automatically logs the start time of that span" do
      Tracer.with_config(tracer_opts).find_or_create.apply do |tracer|
       tracer.apply_new_span do |trace|
         expect(trace.to_hash[:spans].last[:start_time]).to be > 0
       end
      end
    end

    it "assigns a name to the created span if one is given" do
      tracer = Tracer.with_config(tracer_opts).find_or_create({"name" => "fubar2"})
      expect(tracer.to_hash[:spans].first[:name]).to eq("fubar2")
    end

    it "evaluates post process blocks in the context of the current span" do
      restart_celluloid
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.post_process("foo") do
        x = 2
        10.times { x = x*2 }
        x
      end
      tracer.apply do; end

      expected_hash = {"foo" => 2048 }
      expect(tracer.to_hash[:spans].first[:annotations].first).to include(expected_hash)
    end

    it "executes any post process blocks associated with the current span when its stopped" do
      restart_celluloid
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.apply do |trace|
        trace.post_process("foo") do
          x = 2
          10.times { x = x*2 }
          x
        end
      end

      processed_annotations = tracer.to_hash[:spans].first[:annotations]
      expect(processed_annotations.size).to eq(1)
      expect(processed_annotations.first["foo"]).to eq(2048)
    end

    it "terminates the trace once its stopped" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.apply do
        expect(Telemetry::Tracer.fetch).to be_in_progress
        2*2
      end
      expect(Telemetry::Tracer.fetch).not_to be_in_progress
    end

    it "stops all spans attached to the trace that's stopped" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.apply do |trace|
        expect(trace.to_hash[:spans].size).to eq(1)
        trace.apply_new_span("newspan") do |trace2|
          expect(tracer.to_hash[:spans].size).to eq(2)
        end
      end
      expect(tracer.to_hash[:spans].size).to eq(2)

      tracer.to_hash[:spans].each do |span|
        expect(span[:duration]).not_to be_nil
      end
    end

    it "cannot reapply a stale trace" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.apply { 2*2 }
      expect{tracer.apply{"foobar"}}.to raise_error(TraceProcessedException)
    end

    it "bumps the current span if the current span has been processed" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      span1_id = tracer.to_hash[:current_span_id]
      tracer.apply_new_span("foobar") do |tracer|
        expect(tracer.to_hash[:current_span_id]).not_to eq(span1_id)
      end
      expect(tracer.to_hash[:current_span_id]).to eq(span1_id)
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
      tracer.apply do |trace|
        trace.apply_new_span do |trace2|
          2*2
        end
        expect(trace.to_hash[:spans].last[:duration]).to be > 0
        expect(trace.to_hash[:spans].first[:duration]).to eq("NaN")
      end
      expect(tracer.to_hash[:spans].first[:duration]).to be > 0
    end

    it "can apply a new span around a given block of code" do
      tracer = Tracer.with_config(tracer_opts).find_or_create

      current_span_id = tracer.to_hash[:current_span_id]
      tracer.apply_new_span do |trace|
        new_span_id = tracer.to_hash[:current_span_id]
        expect(new_span_id).to eq(trace.to_hash[:spans].last[:id])
        expect(new_span_id).not_to eq(current_span_id)
      end
      expect(tracer.to_hash[:spans].size).to eq(2)
    end

    it "can apply a new span with an optional name parameter" do
      tracer = Tracer.with_config(tracer_opts).find_or_create

      tracer.apply_new_span("foo") do |trace|
        expect(trace.to_hash[:spans].last[:name]).to eq("foo")
      end
    end

    it "takes an optional span_name when applied around a block" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.apply("foo") do |trace|
        expect(trace.to_hash[:spans].first[:name]).to eq("foo")
      end
    end

    it "takes an optional span name when applied" do
      tracer = Tracer.with_config(tracer_opts).find_or_create
      tracer.apply("foo") do |trace|
      end
      expect(tracer.to_hash[:spans].first[:name]).to eq("foo")
    end

    it "annotates the current trace only if its allowed to run" do
      Tracer.config = tracer_opts

      tracer = Tracer.with_override(false).fetch
      expect(tracer.enabled?).to be_false
      tracer.annotate("key", "value")
      expect(tracer.to_hash).to be_empty

      tracer = Tracer.with_override(true).fetch
      expect(tracer.enabled?).to be_true
      tracer.annotate("key", "value")

      aggregated_annotations = tracer.to_hash[:spans].map{|span| span[:annotations]}.flatten
      expect(aggregated_annotations.size).to eq(1)

      expected_hash = {"key" => "value"}
      expect(aggregated_annotations.first).to include(expected_hash)
    end

    it "stores a proc for post process only if its allowed to run" do
      Tracer.config = tracer_opts

      tracer = Tracer.with_override(false).fetch
      expect(tracer.enabled?).to be_false
      tracer.post_process("key") do
        2*2
      end
      expect(tracer.to_hash).to be_empty


      tracer = Tracer.with_override(true).fetch
      expect(tracer.enabled?).to be_true
      tracer.apply do |trace|
        trace.post_process("key") do
          2*2
        end
      end
      annotations = tracer.to_hash[:spans].first[:annotations]
      expect(annotations.size).to eq(1)

      expected_hash = {"key" => 4}
      expect(annotations.first).to include(expected_hash)
    end

    it "anything that's not whitelisted for the current span results in a NoMethodError" do
      tracer = Tracer.with_config(tracer_opts).with_override(true).fetch
      expect{tracer.foo}.to raise_error(NoMethodError)
    end

    it "returns the current_span id if its enabled" do
      tracer = Tracer.with_config(tracer_opts).with_override(true).fetch
      expect(tracer).to be_enabled
      expect(tracer.current_span_id).not_to be_nil
      tracer.apply do; end

      tracer = Tracer.with_config(tracer_opts).with_override(false).fetch
      expect(tracer).not_to be_enabled
      expect(tracer.current_span_id).to be_nil
    end
  end
end
