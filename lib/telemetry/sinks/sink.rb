require "net/http"
require "logger"

module Telemetry
  module Sinks

    class Sink

      def initialize(opts, error_logger)
        log_to_disk, http_endpoint = opts[:log], opts[:http_endpoint]
        @error_logger = error_logger
        begin
          if !log_to_disk.nil?
            @_sink = LogSink.new(log_to_disk)
          else
            @_sink = HTTPSink.new(http_endpoint)
          end
        rescue Exception => ex
          @error_logger.error ex.backtrace.join("\n")
        end
      end

      def process(trace)
        begin
          @_sink.process(trace)
        rescue Exception => ex
          @error_logger.error ex.backtrace.join("\n")
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
        @http.post('/trace',
                   trace.to_json,
                   {'Content-Type' => 'application/json', 'Accept' => 'application/json'})
      end
    end
  end
end
