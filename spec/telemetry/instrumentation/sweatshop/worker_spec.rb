require "spec_helper"
require "telemetry/tracer"
require "telemetry/instrumentation/sweatshop/worker"

module Sweatshop
  class TestWorker < Worker
    def self.enqueue_without_trace(task, *args)
      task[:args]
    end

    def self.do_task_without_trace(task)
      task[:args]
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

    it "appends the trace information to the outgoing task" do
      tracer = Telemetry::Tracer.with_config(tracer_opts).fetch
      tracer.apply("span1") do |trace|
        result = TestWorker.enqueue(task)

        trace_headers = result[-1]
        expect(trace_headers).to include({Telemetry::TRACE_HEADER_KEY => tracer.id})
        expect(trace_headers).to include({Telemetry::SPAN_HEADER_KEY => tracer.current_span_id})
      end
    end


    it "strips the dequeued task of the tracer bits" do
      task[:args] << trace_headers
      result = TestWorker.do_task(task)
      expect(result).to eq(args)
    end

    it "stays idempotent if the dequeued task does not carry tracer bits" do
      result = TestWorker.do_task(task)
      expect(result).to eq(args)
    end

    it "still strips the incoming dequeued task off tracer bits even if the tracer is switched off" do
      Telemetry::Tracer.instance_variable_set(:@config, nil)
      Telemetry::Tracer.config = tracer_opts.merge({"enabled" => false})
      expect(Telemetry::Tracer.run?).to be_false

      task[:args] << trace_headers
      result = TestWorker.do_task(task)
      expect(result).to eq(args)
    end
  end
end
