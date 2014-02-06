require "test_helper"
require "./lib/telemetry/tracer"

module Telemetry

  class Tracer
    #reset the tracer for testing purposes
    class << self
      def reset
        Tracer.instance_variable_set("@tracer", nil)
      end
      alias_method :new!, :reset
    end
  end

  describe Tracer do

    def teardown
      Tracer.reset
    end

    it "loads a new trace if one does not exist" do
      tracer = Tracer.current
      assert_equal Tracer, tracer.class
    end

    it "it uses the current trace if it does exist" do
      tracer1 = Tracer.find_or_create
      tracer2 = Tracer.find_or_create
      assert_equal tracer1, tracer2
    end

    it "initializes itself with a trace id if one is passed" do
      trace_id = "abc123"
      tracer = Tracer.current({:trace_id => trace_id, :parent_span_id => "fubar"})
      assert_equal trace_id, tracer.id
    end

    it "generates a 64bit id for itself if a trace_id is not supplied" do
      tracer = Tracer.current
      assert_equal 8, tracer.id.size
    end

    #we don't want to raise exceptions unless they can be logged somewhere
    it "markes itself as dirty and gives a reason if either trace_id is present but parent span id isn't" do
      tracer = Tracer.current({:trace_id => "fubar123"})
      assert tracer.dirty?
      assert_equal "trace_id present; parent_span_id not present.", tracer.reason
    end

    it "markes itself as dirty if trace id is not present but parent_span_id is" do
      tracer = Tracer.current({:parent_span_id => "fubar123"})
      assert tracer.dirty?
      assert_equal "trace_id not present; parent_span_id present. Auto generating trace id", tracer.reason
    end

    it "comes with a brand new span out of the box" do
      tracer = Tracer.current
      assert_equal tracer.spans.size, 1
      assert tracer.spans.first.instance_of?(Span)
    end

    it "passes any annotations to the current span" do
      tracer = Tracer.current
      assert tracer.current_span.annotations.empty?
      tracer.annotate({"boo radley" => "stayed in because he wanted to"})
      assert_equal 1, tracer.current_span.annotations.size
    end

    it "passes all options except trace_id and parent_span_id to an internal runner object which tells it whether ot not to run" do
      opts = {:enabled => true, 
              :foo => "bar", 
              :parent_span_id => "parent123",
              :trace_id => "trace123"}
      tracer = Tracer.current(opts)
      assert_equal opts, tracer.runner.opts
    end

    it "accepts an override flag which it passes to the runner object" do
      tracer = default_tracer
      assert_equal true, tracer.run?

      tracer.override = false
      assert_equal false, tracer.run?
    end

    it "logs the start time of the trace when started" do
      tracer = default_tracer
      tracer.start
      assert_equal true, !tracer.start_time.nil?
    end

    it "logs the end time of the trace when stopped" do
      tracer = default_tracer
      tracer.stop
      assert_equal true, !tracer.stop_time.nil?
    end

    it "stopping a trace before starting it marks it as dirty" do
      tracer = default_tracer
      assert_equal nil, tracer.start_time
      tracer.stop
      assert_equal true, tracer.dirty?
    end

    it "applying a trace around a block logs the start and end times" do
      tracer = default_tracer
      tracer.apply do
        2*2
      end
      assert_equal true, !tracer.start_time.nil?
      assert_equal true, !tracer.stop_time.nil?
    end

    it "applying a trace yields the trace so annotations can be added to it" do
      annotation = {:foo => "bar"}
      tracer = default_tracer
      tracer.apply do |trace|
        assert_equal 0, trace.annotations.size
        trace.annotate(annotation)
        assert_equal 1, trace.annotations.size
      end
    end

    it "can be started only if its allowed to run" do
      tracer = default_tracer({:enabled => false})
      assert_equal false, tracer.run?
      tracer.start
      assert_equal true, tracer.start_time.nil?
    end

    it "can be applied only if its allowed to run" do
      tracer = default_tracer({:enabled => false})
      assert_equal false, tracer.run?
      tracer.apply do |trace|
        assert_equal true, trace.nil?
      end
    end

    #TODO logging annotations at start_trace time is an enhancement for now. 
    # Do this last of all
    #it "starting a trace optionally takes a request hash out of which requested variables are stored as annotations" do
    #  opts = {:enabled => true, :sample => {:number_of_requests => 1, :out_of => 1}}
    #  Tracer.reset
    #  tracer = Tracer.current(opts)
    #  request_env = {:foo => "bar"}
    #  tracer.start_trace(request_env)
    #  assert_equal 1, tracer.annotations.size
    #  assert_equal annotation, tracer.annotations.first
    #end

    private
    def default_tracer(override_opts={})
      Tracer.reset
      Tracer.current(opts.merge!(override_opts))
    end

    def opts
      {:enabled => true, :sample => {:number_of_requests => 1, :out_of => 1}}
    end
  end
end
