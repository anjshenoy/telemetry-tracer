require "net/http"
require "logger"
require "forwardable"

module Telemetry
  module Sinks

    class Sink
      def initialize(opts)
        log_to_disk, http_endpoint = opts[:log], opts[:http_endpoint]
        if !log_to_disk.nil?
          @_sink = LogSink.new(log_to_disk)
        else
          @_sink = HTTPSink.new(http_endpoint)
        end
      end

      def method_missing(method_name, *args)
        if @_sink.respond_to?(method_name)
          @_sink.send(method_name, *args)
        else
          super
        end
      end
    end

    class LogSink
      def initialize(opts={})
        filename = opts[:filename] || "telemetry_tracer.log"
        directory = opts[:directory]
        @logger = ::Logger.new(directory + "/" + filename)
      end

      def process(trace)
        @logger.info(trace.to_json)
      end
    end


    class HTTPSink
      def initialize(opts={})
        @http = Net::HTTP.new(opts[:server], opts[:port])
      end

      def process(trace)
        begin
          @http.post('/trace',
                     trace.to_json,
                     {'Content-Type' => 'application/json', 'Accept' => 'application/json'})
        rescue Exception => ex
          Telemetry::ErrorLogger.error ex.backtrace.join("\n")
        end
      end
    end
  end
end
