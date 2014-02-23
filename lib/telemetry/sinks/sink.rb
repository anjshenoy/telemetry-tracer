require "net/http"
require "logger"

module Telemetry
  module Sinks

    class Sink

      def initialize(logfile, http_end_point, error_logger)
        @error_logger = error_logger
        begin
          if !logfile.nil?
            @_sink = LogSink.new(logfile)
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
      def initialize(logfile)
        @logger = ::Logger.new(logfile)
      end

      def process(trace)
        @logger.info(trace.to_json)
      end
    end


    class HTTPSink
      def initialize(opts={})
        @http = Net::HTTP.new(opts["server"], opts["port"])
      end

      def process(trace)
        @http.post('/trace',
                   trace.to_json,
                   {'Content-Type' => 'application/json', 'Accept' => 'application/json'})
      end
    end
  end
end
