require "test_helper"
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
      assert_equal tracer1, tracer2
    end

    it "returns the currently existing trace" do
      Tracer.reset_with_config
      tracer = Tracer.current
      assert_equal nil, tracer

      tracer = Tracer.find_or_create
      assert_equal Tracer, tracer.class
    end

    it "initializes itself with a trace id if one is passed" do
      trace_id = "abc123"
      tracer = default_tracer({"trace_id" => trace_id, "parent_span_id" => "fubar"})
      assert_equal trace_id, tracer.id
    end

    it "generates a 64bit id for itself if a trace_id is not supplied" do
      tracer = default_tracer
      assert_equal 8, tracer.id.size
    end

    #we don't want to raise exceptions unless they can be logged somewhere
    it "markes itself as dirty and gives a reason if either trace_id is present but parent span id isn't" do
      tracer = default_tracer({"trace_id" => "fubar123"})
      assert tracer.dirty?
      assert_equal "trace_id present; parent_span_id not present.", tracer.to_hash[:tainted]
    end

    it "markes itself as dirty if trace id is not present but parent_span_id is" do
      tracer = default_tracer({"enabled" => true, "parent_span_id" => "fubar123"})
      assert_equal true, tracer.dirty?
      assert_equal "trace_id not present; parent_span_id present. Auto generating trace id", tracer.to_hash[:tainted]
    end

    it "comes with a brand new span out of the box" do
      tracer = default_tracer
      assert_equal tracer.spans.size, 1
      assert tracer.spans.first.instance_of?(Span)
    end

    it "passes any annotations to the current span" do
      tracer = default_tracer
      assert tracer.current_span.annotations.empty?
      tracer.annotate("UserAgent", "Firefox")
      assert_equal 1, tracer.current_span.annotations.size
    end

    it "only does initializations if its allowed to run" do
      tracer = default_tracer({"enabled" => false, "trace_id" => "123", "parent_span_id" => "234"})
      assert_equal nil, tracer.spans
      assert_equal nil, tracer.id
      assert_equal nil, tracer.current_span
    end

    it "accepts an override flag which it passes to the runner object" do
      tracer = default_tracer
      assert_equal true, tracer.run?

      tracer.override = false
      assert_equal false, tracer.run?
    end

    it "runs the start method of a trace only if its allowed to run" do
      tracer = default_tracer({"enabled" => false})
      assert_equal false, tracer.in_progress?
      tracer.start
      assert_equal false, tracer.in_progress?
    end

    it "runs the stop method of a trace only if its allowed to run" do
      tracer = default_tracer({:enabled => false})
      assert_equal false, tracer.in_progress?
      tracer.stop
      assert_equal false, tracer.in_progress?
    end

    it "turns off the progress sign after its been stopped" do
      tracer = default_tracer
      assert_equal false, tracer.in_progress?
      tracer.start
      assert_equal true, tracer.in_progress?
      tracer.stop
      assert_equal false, tracer.in_progress?
    end

    it "applying a trace around a block logs the start and end times for the current span" do
      tracer = default_tracer
      tracer.apply do
        2*2
      end
      assert_equal true, !tracer.current_span.start_time.nil?
      assert_equal true, !tracer.current_span.stop_time.nil?
    end

    it "applying a trace yields the trace so annotations can be added to it" do
      tracer = default_tracer
      tracer.apply do |trace|
        assert_equal 0, trace.annotations.size
        trace.annotate("foo", "bar")
        assert_equal 1, trace.annotations.size
      end
    end

    it "can be started only if its allowed to run" do
      tracer = default_tracer({"enabled" => false})
      assert_equal false, tracer.run?
      tracer.start
      assert_equal false, tracer.in_progress?
    end

    it "can be applied only if its allowed to run" do
      tracer = default_tracer({"enabled" => false})
      assert_equal false, tracer.run?
      tracer.apply do |trace|
        assert_equal true, trace.nil?
      end
    end

    it "sets the flushed state to true once its flushed" do
      tracer = default_tracer
      assert_equal false, tracer.flushed?
      tracer.stop
      assert_equal true, tracer.flushed?
    end

    it "starting a new span makes the current span the parent span" do
      tracer = default_tracer
      previous_span = tracer.current_span
      new_span = tracer.start_new_span("fubar2")
      assert_equal "fubar2", new_span.name
      assert_equal true, (new_span.id != previous_span.id)
      assert_equal true, new_span.parent_span_id == previous_span.id
      assert_equal true, (new_span.trace_id == previous_span.trace_id)
    end

    it "assigns a name to the created span if one is given" do
      tracer = default_tracer(opts.merge({"name" => "fubar2"}))
      assert_equal "fubar2", tracer.current_span.name
    end

    it "passes blocks to be post processed to the current span" do
      restart_celluloid
      tracer = default_tracer
      tracer.post_process("foo") do
        x = 2
        10.times { x = x*2 }
        x
      end
      assert_equal true, tracer.current_span.post_process_blocks["foo"].is_a?(Celluloid::Future)
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
      processed_annotations = tracer.to_hash[:current_span][:annotations]
      assert_equal false, processed_annotations.empty?
      assert_equal 2048, processed_annotations.first["foo"]
    end

    it "terminates the trace once its stopped" do
      tracer = default_tracer
      tracer.apply do
        assert_equal false, Telemetry::Tracer.current.nil?
        2*2
      end
      assert_equal true, Telemetry::Tracer.current.nil?
    end

    private
    def default_tracer(override_opts={})
      Tracer.find_or_create(opts.merge!(override_opts))
    end

    def opts
      {"enabled" => true,
       "logger" => "/tmp/tracer.log",
       "sample" => {"number_of_requests" => 1, 
                   "out_of" => 1}}
    end
  end
end
