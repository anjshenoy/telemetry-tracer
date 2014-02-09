module Rack
  class RequestTracer
    def initialize(app, options = {})
      @app, @options = app, options
    end

    def call(env)
      trace_id = env[header_hash_name('X-Telemetry-TraceId')]
      span_id = env[header_hash_name('X-Telemetry-SpanId')]

      tracer_opts ={:trace_id => trace_id, 
                    :span_id => span_id,
                    :name => env['SCRIPT_NAME'] + env['PATH_INFO']}

      current_span = Telemetry::Tracer.current(tracer_opts).current_span
      current_span.annotate('ServerReceived')
      #TODO: this should come from a config.
      current_span.annotate('ServiceName', 'unknown rails - update telemetry-ruby to include')

      status, headers, response = @app.call(env)

      current_span.annotate('ServerSent')
      current_span.end

      [status, headers, response]
    end

    def header_hash_name(name)
      'HTTP_' + name.upcase.gsub('-', '_')
    end
  end
end
