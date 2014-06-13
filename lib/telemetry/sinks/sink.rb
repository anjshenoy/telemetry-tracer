require "net/http"
require "logger"

module Telemetry
  class MissingSinkDeviceException < Exception; end
  class ErrorLogDeviceNotFound < Exception; end

  module Sinks
    class Sink

      def initialize(logfile, http_endpoint, error_logger, in_memory=false)
        if !in_memory
          raise MissingSinkDeviceException if logfile.nil? && (http_endpoint.nil? || http_endpoint.empty?)
          raise ErrorLogDeviceNotFound if error_logger.nil?
        end

        @error_logger = error_logger
          if logfile
            @_sink = LogSink.new(logfile)
          elsif http_endpoint
            @_sink = HTTPSink.new(http_endpoint)
          elsif in_memory
            @_sink = InMemorySink.new
          end
      end

      def process(trace)
        begin
          @_sink.process(trace)
        rescue Exception => ex
          @error_logger.error(ex.message << "Trace in JSON \n" << trace.to_json)
          @error_logger.error(ex.backtrace.join("\n"))
        end
      end

      def method_missing(sym, *args, &block)
        if @_sink.respond_to?(sym)
          return @_sink.send(sym, *args, &block)
        end
        super
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

    class InMemorySink
      def initialize
        @@traces ||= []
      end

      def process(trace)
        @@traces += trace.spans
      end

      #TODO: rename traces to something more pertinent
      def traces
        self.class.traces
      end

      def self.traces
        @@traces
      end

      def self.flush!
        @@traces = []
      end
    end
  end
end
