require "zephyr"

class Zephyr

  def perform_with_trace(method, path_components, headers, expect, timeout, data=nil)
    result = nil
    span_name = uri(path_components).to_s
    annotations = [["UserAgent", "Zephyr"], ["ClientSent", ""]]
    tracer = Telemetry::Tracer.fetch(headers)
    tracer.apply(span_name, annotations) do |trace|
      begin
        headers.merge!(trace.headers)
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

end
