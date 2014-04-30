require "zephyr"

class Zephyr

  def perform_with_trace(method, path_components, headers, expect, timeout, data=nil)
    result = nil
    span_name = uri(path_components).to_s
    annotations = [["UserAgent", "Zephyr"], ["ClientSent", ""]]
    tracer = Telemetry::Tracer.fetch(trace_bits(headers))
    tracer.apply(span_name, annotations) do |trace|
      begin
        headers.merge!(trace_headers(trace))
        result = perform_without_trace(method, path_components, headers, expect, timeout, data)
      rescue Exception => e
        trace.annotate('ClientException', "#{e.class.to_s} #{e.message}")
        raise e
      ensure
        trace.annotate('ClientReceived', "")
      end
    end

    result
  end

  alias_method :perform_without_trace, :perform
  alias_method :perform, :perform_with_trace

  def trace_bits(headers)
    {"trace_id"       => headers["X-Telemetry-TraceId"],
     "parent_span_id" => headers["X-Telemetry-SpanId"]}
  end

  def trace_headers(trace)
    {"X-Telemetry-TraceId" => trace.id,
     "X-Telemetry-SpanId"  => trace.current_span_id}
  end
end
