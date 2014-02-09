class Zephyr
  alias_method :old_perform, :perform if method_defined?(:perform)

  def perform(method, path_components, headers, expect, timeout, data=nil)
    span = Telemetry::Tracer.current.start_new_span(uri(path_components).to_s)
    span.annotate('UserAgent', 'Zephyr')
    span.annotate('ClientSent')

    begin
      old_perform(method, path_components, headers, expect, timeout, data)
    rescue Exception => e
      span.annotate('ClientException', e.backtrace.join("\n"))
      raise
    ensure
      span.annotate('ClientReceived')
      span.end
    end
  end
end
