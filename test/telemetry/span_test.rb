require "test_helper"
require "telemetry/span"
require "telemetry/tracer"
require "socket"

module Telemetry
  describe Span do
    let(:tracer) { default_tracer }
    let(:span)   { Span.new(opts) }

    it "defaults to a root span if no parent_span_id is supplied" do
      assert span.root?
    end

    it "is attached to a trace" do
      assert_equal tracer, span.tracer
    end

    it "sets itself up with a human reable name if one is supplied" do
      span = Span.new({:name => "fubar"})
      assert_equal "fubar", span.name
    end

    it "gets its own  4byte id" do
      assert span.id.instance_of?(Fixnum)
      assert 8, span.id.size
    end

    it "id is different from the parent_span_id if one is supplied" do
      span = Span.new({:parent_span_id => "fubar123"})
      assert span.id != span.parent_span_id
    end

    it "has a parent_span if a parent_span_id is supplied" do
      parent_span_id = "fubar123"
      span = Span.new({:parent_span_id => parent_span_id})
      assert_equal span.parent_span_id, parent_span_id
      assert !span.root?
    end

    it "has zero to many annotations" do
      assert span.annotations.empty?
    end

    it "logs a start time in nano seconds when its initialized" do
      span.start
      time_in_nanos = (Time.now.to_f * 1000000000).to_i
      assert span.start_time < time_in_nanos
    end

    it "stores the process id its executing on" do
      assert_equal Process.pid, span.pid
    end

    it "stores the fully qualified hostname its executing on" do
      assert_equal Socket.gethostname, span.hostname
    end

    it "logs the start time of the span when started" do
      span.start
      assert_equal true, !span.start_time.nil?
    end

    it "logs the end time of the trace when stopped" do
      span.stop
      assert_equal true, !span.stop_time.nil?
    end

    it "creates annotations if any are supplied at create time" do
      annotation = {:service => "SplendidService"}
      span = Span.new({:annotations => annotation})
      assert_equal 1, span.annotations.size
      assert_equal annotation, span.annotations.first.params
    end

    it "ignores an annotation if the message value is empty and if the ignore_if_blank option is set" do
      assert_equal true, span.annotations.empty?

      span.annotate("foo", "")
      assert_equal true, span.annotations.empty?

      span.annotate("foo", "bar")
      assert_equal 1, span.annotations.size

      #allow if blank
      span.annotate("eep", nil, nil, false)
      assert_equal 2, span.annotations.size
    end

    it "allows you to add a block of code to post process later" do
      restart_celluloid
      span = Span.new
      assert_equal true, span.post_process_blocks.empty?
      span.post_process("foo") do 
        x = 2
        10.times { x = x*2 }
        x
      end
      assert_equal 1, span.post_process_blocks.size
      assert_equal true, span.post_process_blocks["foo"].is_a?(Celluloid::Future)
    end

    it "executes any post process blocks and stores the results as new annotations when a span is stopped" do
      restart_celluloid
      span.start
      assert_equal true, span.annotations.empty?
      span.post_process("foo") do
        x = 2
        10.times { x = x*2 }
        x
      end
      span.post_process("bar") do
        y = 3
        until(y < 0) do
          y -= 1
        end
        y
      end
      assert_equal 2, span.post_process_blocks.size
      assert_equal 0, span.annotations.size
      span.stop
      assert_equal 2, span.annotations.size
      processed_hash1 = {"foo" => 2048}
      processed_hash2 = {"bar" => -1}
      assert_equal processed_hash1, span.annotations.first.params
      assert_equal processed_hash2, span.annotations.last.params
    end

    it "logs the time to process for each post process block executed" do
      restart_celluloid
      span.start
      assert_equal true, span.annotations.empty?
      span.post_process("foo") do
        x = 2
        10.times { x = x*2 }
        x
      end
      span.stop
      assert_equal true, !span.annotations.first.time_to_process.nil?
    end

    it "raises an exception if a span is restarted" do
      span.start
      span.stop
      assert_raises SpanStoppedException do 
        span.start
      end
    end

    it "raises an exception if a span is stopped" do
      span.start
      span.stop
      assert_raises SpanStoppedException do 
        span.stop
      end
    end


    private
    def opts
      {:tracer => tracer}
    end
  end
end
