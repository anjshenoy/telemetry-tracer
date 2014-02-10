require "./lib/telemetry/runner"
require "./lib/telemetry/sinks/sink"
require "./lib/telemetry/loggers/error_logger"
require "logger"
require "yaml"

module Telemetry
  #spits out runner, sinks, loggers 
  #for the telemetry agent to use
  class Config
    attr_reader :runner, :sink, :error_logger

    def initialize(opts={})
      config_file = opts[:config_file]
      if config_file
        opts = read_from_config_file(config_file)
      end
      @runner = Runner.new(opts["enabled"], {"sample" => opts["sample"]}, opts["run_on_hosts"])
      if @runner.run?
        @error_logger = Telemetry::Loggers.error_logger(opts["error_logger"])
        @sink = Sinks::Sink.new(opts["logger"], opts["http_endpoint"], @error_logger)
      end
    end

    private
    def read_from_config_file(filename)
      YAML.load_file(filename)
    end
  end
end
