require "logger"

module Telemetry
  class Logger
    class ErrorLogger
      def initialize(opts={})
        filename = opts[:filename] || "tracer_errors.log"
        directory = opts[:directory]
        @error_logger = ::Logger.new(directory + "/" + filename)
        @error_logger.formatter = ::Logger::Formatter.new
      end
    end
  end
end
