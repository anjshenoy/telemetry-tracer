require "spec_helper"
require "telemetry/tracer"
require "telemetry/instrumentation/sweatshop/worker"

module Sweatshop
  class TestWorker < Worker
    def self.enqueue_without_trace(task, *args)
      task[:args]
    end

    def self.do_task_without_trace(task)
      task[:args] if task.is_a?(Hash)
    end
  end

  describe TestWorker do
    let(:args) { [{:foo => 1, :bar => "abc"}]}
    let(:task)  { {:args=>  args,
                   :method => "hello",
                   :uid => "abcd1234",
                   :queued_at => 1399253770.1600323
    }}
    let(:trace_headers) { {Telemetry::TRACE_HEADER_KEY => 1233467890,
                           Telemetry::SPAN_HEADER_KEY  => 12345} }

    before do
      Telemetry::Tracer.reset_with_config
    end

    it "appends the trace information to the outgoing task" do
      tracer = Telemetry::Tracer.with_config(tracer_opts).fetch
      tracer.apply("span1") do |trace|
        result = TestWorker.enqueue(task)

        expect(result.size).to eq(2)
        expect(result.last).to eq({:tracer => tracer.headers})
      end
    end

    it "does not append anything to the outgoing task if the tracer is not allowed to run" do
      Telemetry::Tracer.config = tracer_opts.merge({"enabled" => false})
      Telemetry::Tracer.fetch.apply("span1") do |trace|
        result = TestWorker.enqueue(task)

        expect(result.size).to eq(1)
        expect(result).to eq([{:foo => 1, :bar => "abc"}])
      end
    end

    it "strips the dequeued task off the tracer bits" do
      task[:args] << {:tracer => trace_headers}
      result = TestWorker.do_task(task)
      expect(result).to eq([{:foo => 1, :bar => "abc"}])
    end

    it "recreates a trace off the dequeued tracer bits" do
      Telemetry::Tracer.config = in_memory_tracer_opts
      task[:args] << {:tracer => trace_headers}
      TestWorker.do_task(task)

      spans = Telemetry::Sinks::InMemorySink.traces_with_spans
      expect(spans.size).to eq(1)
      expect(spans.first[:trace_id]).to eq(trace_headers[Telemetry::TRACE_HEADER_KEY])
      expect(spans.first[:parent_span_id]).to eq(trace_headers[Telemetry::SPAN_HEADER_KEY])
    end

    it "stays idempotent if the dequeued task does not carry tracer bits" do
      Telemetry::Tracer.config = tracer_opts
      expect(Telemetry::Tracer.run?).to be_true

      task[:args] << {:tracer => {}}
      result = TestWorker.do_task(task)
      expect(result).to eq([{:foo => 1, :bar => "abc"}])
    end

    it "a trace is not initiated if there are no tracer bits in the header" do
      task[:args] << {:tracer => {}}
      TestWorker.do_task(task)

      expect(Telemetry::Tracer.fetch.enabled?).to be_false
    end

    it "runs a trce if there are tracer bits in the trace headers" do
      Telemetry::Tracer.config = tracer_opts
      expect(Telemetry::Tracer.run?).to be_true

      task[:args] << {:tracer => {Telemetry::TRACE_HEADER_KEY => 1231231}}
      TestWorker.do_task(task)

      expect(Telemetry::Tracer.fetch.enabled?).to be_true
    end

    it "strips the tracer bits coming off the queue only if they are enqueued" do
      Telemetry::Tracer.config = tracer_opts
      expect(task[:args].size).to be(1)

      result = TestWorker.do_task(task)
      expect(result).to eq([{:foo => 1, :bar => "abc"}])
    end

    it "strips the tracer bits only if the task that's popped off the queue is a hash" do
      Telemetry::Tracer.config = tracer_opts
      task = [12345, "some object"]

      result = TestWorker.do_task(task)
      expect(result).to eq(nil)
    end

    it "strips the tracer bits only if the task that's popped off the queue has an args key " do
      Telemetry::Tracer.config = tracer_opts
      task[:args] = nil

      result = TestWorker.do_task(task)
      expect(result).to eq(nil)
    end

    it "strips the tracer bits coming off the queue only if they are enqueued and in trace format" do
      task[:args] << nil
      expect(task[:args].size).to be(2)

      result = TestWorker.do_task(task)
      expect(result).to eq([{:foo => 1, :bar => "abc"}, nil])

      #replace nil with number
      args[1] = "123"
      expect(task[:args].size).to be(2)

      result = TestWorker.do_task(task)
      expect(result).to eq([{:foo => 1, :bar => "abc"}, "123"])

      #last element is an empty hash - pass it downstream as it
      #tracer hash format is {:tracer => {"X-Telemetry-TraceId" => 123, "X-Telemetry-SpanId" => 456}}
      args[1] = {}
      expect(task[:args].size).to be(2)

      result = TestWorker.do_task(task)
      expect(result).to eq([{:foo => 1, :bar => "abc"}, {}])

      #now the incoming args' last element  in the tracer format, 
      #strip out the tracer bits and pass the rest on
      args[1] = {:tracer => {}}
      expect(task[:args].size).to be(2)

      result = TestWorker.do_task(task)
      expect(result).to eq([{:foo => 1, :bar => "abc"}])
    end

    it "still strips the incoming dequeued task off tracer bits even if the tracer is switched off" do
      Telemetry::Tracer.instance_variable_set(:@config, nil)
      Telemetry::Tracer.config = tracer_opts.merge({"enabled" => false})
      expect(Telemetry::Tracer.run?).to be_false

      task[:args] << {:tracer => trace_headers}
      result = TestWorker.do_task(task)
      expect(result).to eq([{:foo => 1, :bar => "abc"}])
    end
  end
end
