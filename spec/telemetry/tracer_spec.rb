require "spec_helper"
require "telemetry/tracer"

module Telemetry
  describe Tracer do
    before do
      Tracer.reset_with_config
      MyAppCache.reset
    end

    it "can set the config separately" do
      Tracer.config = {}
      expect(Tracer.config.runner.enabled?).to be_false
    end

    it "sets the config once during its lifetime" do
      Tracer.config = tracer_opts
      expect(Tracer.config.runner.run?).to be_true

      Tracer.config = {"enabled" => false}
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

    it "stores a proc object as part of its config which it will evaluate and substitute for the override flag" do
      MyAppCache.tracer_enabled = false
      Tracer.config = tracer_opts.merge({"override" => Proc.new{MyAppCache.tracer_enabled}})

      expect(Tracer.override?).to be_false
    end

    it "the override flag can be changed to a new proc any time, if the evaluated proc is not the same as the current override" do
      MyAppCache.tracer_enabled = false
      Tracer.config = tracer_opts.merge({"override" => Proc.new{ MyAppCache.tracer_enabled }})
      expect(Tracer.override?).to be_false

      #no change
      Tracer.override = Proc.new{ MyAppCache.tracer_enabled }
      expect(Tracer.override?).to be_false

      MyAppCache.tracer_enabled = true
      Tracer.override = Proc.new{ MyAppCache.tracer_enabled }
      expect(Tracer.override?).to be_true
    end

    it "allows a proc of code to be stored at any time which is evaluated and substituted for the override flag" do
      Tracer.config = tracer_opts
      expect(Tracer.override?).to be_true

      Tracer.override = Proc.new{MyAppCache.tracer_enabled}
      expect(Tracer.override?).to be_false
    end

    it "has a with_config api which applies the supplied config opts and returns self" do
      expect(Tracer.with_config(tracer_opts).override?).to be_true
    end

    it "preinitializes itself with a default config if not set up with one when fetch is called" do
      Tracer.fetch
      expect(Tracer.config.run?).to be_false
    end

    it "does not reinitialize itself with a new config if one is already set when fetch is called" do
      Tracer.config = tracer_opts
      tracer = Tracer.fetch
      expect(tracer.enabled?).to be_true

      Tracer.config = tracer_opts.merge({"enabled" => false})
      tracer2 = Tracer.fetch
      expect(tracer2.enabled?).to be_true
    end

    # Consider the case for workers: 
    # If you have a cluster of workers eating off a queue, you don't 
    # know which one will process your message.
    # So you only want to fetch the trace based on the 
    # run and override flags.
    it "can elect to run in basic mode only" do
      Tracer.config = tracer_opts.merge!({"run_on_hosts" => "someotherhost"})
      expect(Tracer.run?).to be_false #because hosts dont match
      expect(Tracer.run_basic?).to be_true

      tracer = Tracer.fetch_with_run_basic_mode
      expect(tracer.enabled?).to be_true
    end

    it "behaves the same as the fetch method if the enable flag is off" do
      Tracer.config = tracer_opts.merge!({"enabled" => false})
      expect(Tracer.run?).to be_false #because hosts dont match
      expect(Tracer.run_basic?).to be_false

      tracer = Tracer.fetch_with_run_basic_mode
      expect(tracer.enabled?).to be_false
    end

    it "behaves the same as the fetch method if the override flag is off" do
      Tracer.config = tracer_opts.merge!({"override" => false})
      expect(Tracer.run?).to be_false #because hosts dont match
      expect(Tracer.run_basic?).to be_false

      tracer = Tracer.fetch_with_run_basic_mode
      expect(tracer.enabled?).to be_false
    end

    it "creates a trace if one does not already exist" do
      tracer1 = Tracer.fetch
      tracer2 = Tracer.fetch
      expect(tracer1).to eq(tracer2)
    end

    it "initializes itself with a trace id if one is passed" do
      trace_id = "abc123"
      tracer = Tracer.with_config(tracer_opts).fetch({Telemetry::TRACE_HEADER_KEY => trace_id, 
                                                               Telemetry::SPAN_HEADER_KEY => "fubar"})
      expect(tracer.id).to eq(trace_id)
    end

    it "generates a 64bit id for itself if a trace_id is not supplied" do
      tracer = Tracer.with_config(tracer_opts).fetch
      expect(tracer.id.size).to eq(8)
    end

    it "markes itself as dirty and gives a reason if either trace_id is present but parent span id isn't" do
      tracer = Tracer.with_config(tracer_opts).fetch({Telemetry::TRACE_HEADER_KEY => "fubar123"})
      expect(tracer.spans.first[:tainted]).to eq("trace_id present; parent_span_id not present.")
    end

    it "markes itself as dirty if trace id is not present but parent_span_id is" do
      tracer = Tracer.with_config(tracer_opts).fetch({"enabled" => true, Telemetry::SPAN_HEADER_KEY => "fubar123"})
      expect(tracer.spans.first[:tainted]).to eq("trace_id not present; parent_span_id present. Auto generating trace id")
    end

    it "comes with a brand new span out of the box" do
      tracer = Tracer.with_config(tracer_opts).fetch
      expect(tracer.spans.size).to eq(1)
    end

    it "sets up the current span with a parent span id if one is supplied" do
      trace_headers = {Telemetry::TRACE_HEADER_KEY => 123456789, 
                       Telemetry::SPAN_HEADER_KEY => 456789}
      trace = Tracer.with_config(tracer_opts).fetch(trace_headers)
      expect(trace.spans.size).to eq(1)
      expect(trace.spans.first[:parent_span_id]).to eq(456789)
    end

    it "passes any annotations to the current span" do
      trace = Tracer.with_config(tracer_opts).fetch
      aggregated_annotations = trace.spans.map{|span| span[:annotations]}.flatten
      expect(aggregated_annotations).to be_empty

      trace.annotate("UserAgent", "Firefox")
      current_span = trace.spans.first
      span_annotations = current_span[:annotations]

      expected_hash = {"UserAgent" => "Firefox"}
      expect(span_annotations.first).to include(expected_hash)
    end

    it "only does initializations if its allowed to run" do
      Tracer.config = tracer_opts.merge("enabled" => false)
      expect(Tracer.run?).to be_false

      trace = Tracer.fetch({Telemetry::TRACE_HEADER_KEY => "123", 
                            Telemetry::SPAN_HEADER_KEY => "234"})
      expect(trace.id).to be_nil
      expect(trace.spans).to be_empty
    end

    it "is in progress only once its started and before its stopped" do
      tracer = Tracer.with_config(tracer_opts).fetch

      expect(tracer.in_progress?).to be_false
      tracer.apply do |trace|
        expect(tracer.in_progress?).to be_true
      end
      expect(tracer.in_progress?).to be_false
    end

    it "still finishes processing if the override flag is switched off after a trace starts but before it stops" do
      tracer = Tracer.with_config(tracer_opts).fetch
      expect(tracer.enabled?).to be_true

      aggregated_annotations = tracer.spans.map{|span| span[:annotations]}.flatten
      expect(aggregated_annotations).to be_empty

      tracer.apply do |trace|
        trace.post_process("foo") do
          2*2
        end
        Tracer.override = false
        expect(tracer.enabled?).to be_true
      end

      expected_hash = {"foo" => 4}
      aggregated_annotations = tracer.spans.map{|span| span[:annotations]}.flatten
      expect(aggregated_annotations.size).to eq(1)
      expect(aggregated_annotations.first).to include(expected_hash)
    end

    it "returns the currently executing trace even if the override flag is switched off" do
      tracer = Tracer.with_config(tracer_opts).fetch
      expect(Tracer.override?).to be_true

      tracer.apply do |trace|
        expect(Tracer.fetch).to eq(tracer)

        Tracer.override = false
        expect(Tracer.override?).to be_false
        expect(Tracer.fetch).to eq(tracer)
      end
    end

    it "resets the current trace if it isnt in progress if the override flag is switched off" do
      tracer = Tracer.with_config(tracer_opts).fetch
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
      tracer = Tracer.with_config(tracer_opts).fetch
      tracer.apply do
        expect(tracer.spans.first[:start_time]).to be > 0
        2*2
      end
      expect(tracer.spans.first[:duration]).to be > 0
    end

    it "applying a trace around a block yields the trace so annotations can be added to it" do
      tracer = Tracer.with_config(tracer_opts).fetch
      tracer.apply do |trace|
        aggregated_annotations = tracer.spans.map{|span| span[:annotations]}.flatten
        expect(aggregated_annotations).to be_empty

        trace.annotate("foo", "bar")
        aggregated_annotations = tracer.spans.map{|span| span[:annotations]}.flatten
        expect(aggregated_annotations.size).to eq(1)
      end
    end

    it "can be applied only if its allowed to run" do
      Tracer.config = tracer_opts.merge({"enabled" => false})
      tracer = Tracer.fetch
      expect(tracer.enabled?).to be_false

      tracer.apply do |trace|
        expect(trace.in_progress?).to be_false
      end
    end

    it "allows the program to go through the normal flow of execution if its switched off" do
      Tracer.config = tracer_opts.merge({"enabled" => false})
      tracer = Tracer.fetch

      x = 0
      tracer.apply do |trace|
        x = 2*2
      end

      expect(x).to eq(4)
    end

    it "yields itself if applied" do
      Tracer.with_config(tracer_opts).fetch.apply do |tracer|
        expect(tracer.is_a?(Tracer)).to be_true
      end
    end

    it "can be applied with multiple annotations" do
      annotations = [["UserAgent", "Zephyr"], ["ClientSent", ""]]
      tracer = Tracer.with_config(tracer_opts).fetch
      tracer.apply("foo", annotations) do
        annotations = tracer.spans.first[:annotations]
        expect(annotations.size).to eq(2)
        expect(annotations.first).to include({"UserAgent" => "Zephyr"})
        expect(annotations.last).to include({"ClientSent" => ""})
      end

    end

    it "applying a new span makes the current span the parent span" do
      tracer = Tracer.with_config(tracer_opts).fetch
      previous_span_id = tracer.current_span_id
      tracer.apply do |trace|
        trace.apply("fubar2") do |inner_trace|
          new_span = tracer.spans.last
          expect(new_span[:name]).to eq("fubar2")
          expect(new_span[:id]).not_to eq(previous_span_id)
          expect(new_span[:parent_span_id]).to eq(previous_span_id)
        end
      end
    end

    it "starting a new span automatically logs the start time of that span" do
      Tracer.with_config(tracer_opts).fetch.apply do |tracer|
       tracer.apply do |trace|
         expect(trace.spans.last[:start_time]).to be > 0
       end
      end
    end

    it "assigns a name to the created span if one is given" do
      tracer = Tracer.with_config(tracer_opts).fetch({"name" => "fubar2"})
      expect(tracer.spans.first[:name]).to eq("fubar2")
    end

    it "evaluates post process blocks in the context of the current span" do
      restart_celluloid
      tracer = Tracer.with_config(tracer_opts).fetch
      tracer.post_process("foo") do
        x = 2
        10.times { x = x*2 }
        x
      end
      tracer.apply do; end

      expected_hash = {"foo" => 2048 }
      expect(tracer.spans.first[:annotations].first).to include(expected_hash)
    end

    it "executes any post process blocks associated with the current span when its stopped" do
      restart_celluloid
      tracer = Tracer.with_config(tracer_opts).fetch
      tracer.apply do |trace|
        trace.post_process("foo") do
          x = 2
          10.times { x = x*2 }
          x
        end
      end

      processed_annotations = tracer.spans.first[:annotations]
      expect(processed_annotations.size).to eq(1)
      expect(processed_annotations.first["foo"]).to eq(2048)
    end

    it "cannot reapply a stale trace" do
      tracer = Tracer.with_config(tracer_opts).fetch
      tracer.apply { 2*2 }

      begin
        tracer.apply("boo") do; end
      rescue TraceProcessedException => ex
        expect(ex.message).to include(tracer.id.to_s)
        expect(ex.message).to include(tracer.current_span_id.to_s)
      end
    end

    it "calling apply in the context of a currently executing span starts a newly nested span" do
      tracer = Tracer.with_config(tracer_opts).fetch
      tracer.apply do |trace|
        span1_id = trace.current_span_id
        expect(tracer.current_span_id).to eq(span1_id)
        tracer.apply do |trace2|
          expect(trace.current_span_id).not_to eq(span1_id)
          expect(trace2.spans.last[:parent_span_id]).to eq(span1_id)
        end
      end

    end

    it "only stops the currently executing span if applied around a block" do
      tracer = Tracer.with_config(tracer_opts).fetch
      tracer.apply do |trace|
        trace.apply do; end
        expect(trace.spans.last[:duration]).to be > 0
        expect(trace.spans.first[:duration]).to eq("NaN")
      end
      expect(tracer.spans.first[:duration]).to be > 0
    end

    it "bumps the parent span to the current span if the currently nested span is done" do
      Tracer.config = tracer_opts

      #pattern 1 - parent trace => child trace
      Tracer.fetch.apply do |trace|
        parent_span_id = trace.current_span_id
        trace.apply do |trace2|
          expect(trace2).to eq(trace)
          expect(trace2.current_span_id).not_to eq(parent_span_id)
        end
        expect(trace.current_span_id).to eq(parent_span_id)
      end

      #pattern 2 - parent trace => [child trace1 => child trace2]
      Tracer.fetch.apply do |trace|
        span1_id = trace.current_span_id
        trace.apply do |trace2|
          span2_id = trace2.current_span_id
          trace2.apply do |trace3|
            span3_id = trace2.current_span_id
            expect(trace3.current_span_id).to eq(span3_id)
          end
          expect(trace2.current_span_id).to eq(span2_id)
        end
        expect(trace.current_span_id).to eq(span1_id)
      end

      #pattern 3 - parent trace => [child trace1, child trace2]
      Tracer.fetch.apply do |trace|
        span1_id = trace.current_span_id
        trace.apply do |trace2|
          span2_id = trace2.current_span_id
          expect(trace2.current_span_id).to eq(span2_id)
        end
        expect(trace.current_span_id).to eq(span1_id)
        trace.apply do |trace3|
          span3_id = trace3.current_span_id
          expect(trace3.current_span_id).to eq(span3_id)
        end
        expect(trace.current_span_id).to eq(span1_id)
      end
    end

    it "flushes the trace once all executing spans are stopped" do
      tracer = Tracer.with_config(tracer_opts).fetch
      tracer.apply do |trace|
        trace.post_process("parent_post_process") do
          2*2
        end
        tracer.apply do |trace2|
          trace2.post_process("child_post_process") do
            3*3
          end
        end
        #child span is done
        aggregated_annotations = tracer.spans.map{|span| span[:annotations]}.flatten
        expect(aggregated_annotations).to be_empty
      end

      #parent_span is done => all spans are done. 
      #now trace get flushed and all post_process_blocks should get executed
      aggregated_annotations = tracer.spans.map{|span| span[:annotations]}.flatten
      expect(aggregated_annotations.size).to eq(2)
    end

    it "logs the instrumentation time when stopped" do
      tracer = Tracer.with_config(tracer_opts).fetch

      tracer.apply { 2*2 }
      expect(tracer.spans.first[:time_to_instrument_trace_bits_only]).to be > 0
    end

    it "is no longer in progress once all spans have stopped executing" do
      tracer = Tracer.with_config(tracer_opts).fetch
      tracer.apply do |trace|
        expect(Tracer.fetch).to be_in_progress

        tracer.apply do |trace2|
          expect(Tracer.fetch).to be_in_progress
        end

        #child span is done
        expect(Tracer.fetch).to be_in_progress
      end

      #all spans are done
      expect(Tracer.fetch).not_to be_in_progress
    end

    it "takes an optional span_name when applied around a block" do
      tracer = Tracer.with_config(tracer_opts).fetch
      tracer.apply("foo") do |trace|
        expect(trace.spans.first[:name]).to eq("foo")
      end
    end

    it "re-raises any exceptions raised by instrumentation code and still stops the span" do
      Telemetry::Sinks::InMemorySink.flush!
      tracer = Tracer.with_config(in_memory_tracer_opts).fetch
      expect { tracer.apply("foo") do |trace|
                 raise "Hello"
                end }.to raise_error("Hello")

      #trace still gets flushed
      spans = Telemetry::Sinks::InMemorySink.traces_with_spans

      expect(spans.size).to eq(1)
      expect(spans.first[:name]).to eq("foo")
    end

    it "annotates the current trace only if its allowed to run" do
      Tracer.config = tracer_opts

      tracer = Tracer.with_override(false).fetch
      expect(tracer.enabled?).to be_false
      tracer.annotate("key", "value")
      expect(tracer.spans).to be_empty

      tracer = Tracer.with_override(true).fetch
      expect(tracer.enabled?).to be_true
      tracer.annotate("key", "value")

      aggregated_annotations = tracer.spans.map{|span| span[:annotations]}.flatten
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
      expect(tracer.spans).to be_empty


      tracer = Tracer.with_override(true).fetch
      expect(tracer.enabled?).to be_true
      tracer.apply do |trace|
        trace.post_process("key") do
          2*2
        end
      end
      annotations = tracer.spans.first[:annotations]
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

    it "fetches the headers for the current trace" do
      tracer = Tracer.with_config(tracer_opts).with_override(true).fetch
      expect(Telemetry::Tracer.current_trace_headers).to eq(tracer.headers)
    end

  end
end
