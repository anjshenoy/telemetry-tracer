require "zephyr"

class Zephyr

  def perform_with_trace(method, path_components, headers, expect, timeout, data=nil)
    result = nil
    span_name = uri(path_components).to_s
    annotations = [["UserAgent", "Zephyr"], ["ClientSent", ""]]
    tracer = Telemetry::Tracer.fetch(tracer_bits(headers))
    tracer.apply_with_annotations(span_name, annotations) do |trace|
      begin
        headers["X-Telemetry-TraceId"] = trace.id
        headers["X-Telemetry-SpanId"] = trace.to_hash[:current_span_id]

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

  def tracer_bits(headers)
    {"trace_id"       => headers["X-Telemetry-TraceId"],
     "parent_span_id" => headers["X-Telemetry-SpanId"]}
  end
end
