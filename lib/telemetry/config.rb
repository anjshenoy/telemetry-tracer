require "./lib/telemetry/runner"
require "./lib/telemetry/sinks/sink"
require "logger"

module Telemetry
  #spits out runner, sinks, loggers 
  #for the telemetry agent to use
  class Config
    attr_reader :runner, :sink, :error_logger

    def initialize(opts={})
      @runner = Runner.new(opts[:enabled], {:sample => opts[:sample]}, opts[:run_on_hosts])
      if @runner.run?
        @error_logger = Logger.new(opts[:error_logger])
        @sink = Sinks::Sink.new({:log => opts[:log], :http_endpoint => opts[:http_endpoint]}, @error_logger)
      end
    end

  end
end
