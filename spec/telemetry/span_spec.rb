require "spec_helper"
require "telemetry/span"
require "telemetry/tracer"
require "socket"

module Telemetry
  describe Span do
    let(:tracer) { default_tracer }
    let(:span)   { Span.new(opts) }

    it "defaults to a root span if no parent_span_id is supplied" do
      expect(span.root?).to be_true
    end

    it "is attached to a trace" do
      expect(span.tracer).to eq(tracer)
    end

    it "sets itself up with a human reable name if one is supplied" do
      span = Span.new({:name => "fubar"})
      expect(span.name).to eq("fubar")
    end

    it "gets its own  4byte id" do
      expect(span.id.class).to eq(Fixnum)
      expect(span.id.size).to eq(8)
    end

    it "id is different from the parent_span_id if one is supplied" do
      span = Span.new({:parent_span_id => "fubar123"})
      expect(span.parent_span_id).not_to eq(span.id)
    end

    it "has a parent_span if a parent_span_id is supplied" do
      parent_span_id = "fubar123"
      span = Span.new({:parent_span_id => parent_span_id})
      expect(parent_span_id).to eq(span.parent_span_id)
      expect(span.root?).to be_false
    end

    it "has zero to many annotations" do
      expect(span.annotations).to be_empty
    end

    it "logs a start time in nano seconds when its initialized" do
      span.start
      time_in_nanos = (Time.now.to_f * 1000000000).to_i
      expect(span.start_time).to be <= time_in_nanos
    end

    it "stores the process id its executing on" do
      expect(span.pid).to be(Process.pid)
    end

    it "stores the fully qualified hostname its executing on" do
      expect(span.hostname).to eql(Socket.gethostname)
    end

    it "logs the start time when started" do
      span.start
      expect(span.start_time).not_to be_nil
    end

    it "logs the duration of the span  when stopped" do
      span.start
      span.stop
      expect(span.duration).not_to be_nil
    end

    it "creates annotations if any are supplied at create time" do
      annotation = {:service => "SplendidService"}
      span = Span.new({:annotations => annotation})
      expect(span.annotations.size).to eq(1)
      expect(span.annotations.first.params).to eq(annotation)
    end

    it "ignores an annotation if the message value is empty and if the ignore_if_blank option is set" do
      expect(span.annotations).to be_empty

      span.annotate("foo", "")
      expect(span.annotations).to be_empty

      span.annotate("foo", "bar")
      expect(span.annotations.size).to eq(1)

      #allow if blank
      span.annotate("eep", nil, nil, false)
      expect(span.annotations.size).to eq(2)
    end

    it "allows you to add a block of code to post process later" do
      restart_celluloid
      span = Span.new
      expect(span.post_process_blocks).to be_empty

      span.post_process("foo") do 
        x = 2
        10.times { x = x*2 }
        x
      end

      expect(span.post_process_blocks.size).to eq(1)
      expect(span.post_process_blocks["foo"].class).to eq(Celluloid::Future)
    end

    it "executes any post process blocks and stores the results as new annotations when a span is stopped" do
      restart_celluloid
      span.start
      expect(span.annotations).to be_empty

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
      expect(span.post_process_blocks.size).to eq(2)
      expect(span.annotations).to be_empty

      span.stop
      expect(span.annotations.size).to eq(2)

      processed_hash1 = {"foo" => 2048}
      processed_hash2 = {"bar" => -1}

      expect(span.annotations.first.params).to eq(processed_hash1)
      expect(span.annotations.last.params).to eq(processed_hash2)
    end

    it "logs the time to process for each post process block executed" do
      restart_celluloid
      span.start
      expect(span.annotations).to be_empty

      span.post_process("foo") do
        x = 2
        10.times { x = x*2 }
        x
      end
      span.stop
      expect(span.annotations.first.time_to_process).not_to be_nil
    end

    it "raises an exception if a span is restarted" do
      span.start
      span.stop
      expect {span.start}.to raise_error(SpanStoppedException)
    end

    it "raises an exception if a span is stopped" do
      span.start
      span.stop
      expect {span.stop}.to raise_error(SpanStoppedException)
    end


    it "computes duration of a span only when its been stopped" do
      span.start
      expect(span.duration).to eq("NaN")

      span.stop
      expect(span.duration).not_to be_nil
    end

    it "computes duration of a span only when its been started and stopped" do
      expect(span.duration).to eq("NaN")
    end

    it "allows for itself to be wrapped around a block while yielding itself" do
      span.apply do |yielded_span|
        expect(yielded_span).to eq(span)
        expect(yielded_span.in_progress?).to be_true
        2*2
      end
      expect(span.stopped?).to be_true
    end

    it "takes a span name as an optional parameter when applying itself around a block" do
      span.apply("foo") do |yielded_span|
        expect(yielded_span.name).to eq("foo")
        2*2
      end
    end

    it "takes an optional name parameter when starting" do
      span.start("foo")
      expect(span.name).to eq("foo")
    end

    it "can set the name of the span at any time" do
      expect(span.name).to be_nil
      span.name = "foo"
      expect(span.name).to eq("foo")
    end

    it "only sets the name if one is provided" do
      span.name = nil
      expect(span.name).to be_nil
    end

    it "cannot the name once the span has been stopped" do
      expect(span.name).to be_nil
      span.apply do |span|
        2*2
      end
      expect {span.name="foo"}.to raise_error(SpanStoppedException)
    end

    it "stops progress once its been stopped" do
      span.start
      expect(span.in_progress?).to be_true
      span.stop
      expect(span.in_progress?).to be_false
    end

    private
    def opts
      {:tracer => tracer}
    end
  end
end
