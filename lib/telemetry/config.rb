require "telemetry/runner"
require "telemetry/sinks/sink"
require "telemetry/logger"
require "logger"
require "yaml"
require "core/forwardable_ext"

module Telemetry
  #spits out runner, sinks, loggers 
  #for the telemetry agent to use
  class Config
    extend SimpleForwardable

    attr_reader :runner, :sink, :error_logger

    delegate :run?, :override?, :override=, :to => :runner

    def initialize(opts={})
      config_file = opts[:config_file]
      if config_file
        opts = read_from_config_file(config_file)
      end
      @runner = Runner.new(opts["enabled"], {"sample" => opts["sample"]}, opts["run_on_hosts"])
      if @runner.run?
        @error_logger = Telemetry::Logger.error_logger(opts["error_logger"])
        @sink = Sinks::Sink.new(opts["logger"], opts["http_endpoint"], @error_logger)
      end
    end

    private
    def read_from_config_file(filename)
      YAML.load_file(filename)
    end
  end
end
