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

    it "has an enabled flag" do
      tracer = Tracer.current({:enabled => true})
      assert_equal true, tracer.enabled?
    end

    it "has an option for logging instrumentation time" do
      tracer = Tracer.current({:log_instrumentation_time => true})
      assert_equal true, tracer.log_instrumentation_time?
    end

    it "sets the default for logging instrumentation time to true if its not set" do
      assert_equal true, Tracer.current.log_instrumentation_time?
    end

    it "setting option for logging instrumentation time to false negates the default for the same" do
      tracer = Tracer.current({:log_instrumentation_time => false})
      assert_equal false, tracer.log_instrumentation_time?
    end

    it "accepts a sampling rate out of a default of thousand" do
      tracer = Tracer.current({:sample => {:number_of_requests => 2, :out_of => 1024}})
      assert_equal 2, tracer.sample
      assert_equal 1024, tracer.sample_size
    end

    it "sets a default sampling rate of 1 out of every 1000 requests" do
      tracer = Tracer.current
      assert_equal 1, tracer.sample
      assert_equal 1024, tracer.sample_size
    end

    it "if a host regex is supplied, it runs it only on the hosts in question" do
      tracer = Tracer.current({:run_on_hosts => "fubar-[1-3]"})
      assert_equal false, tracer.matching_host?
    end

    it "runs it on all hosts if a host regex is not supplied" do
      assert_equal true, Tracer.current.matching_host?
    end
  end
end
