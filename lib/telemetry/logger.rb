require "logger"

module Telemetry
  module Logger
    def self.error_logger(file)
      @error_logger ||= ::Logger.new(file)
      @error_logger.formatter = ::Logger::Formatter.new
      @error_logger
    end
  end
end
