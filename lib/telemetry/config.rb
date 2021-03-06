require "telemetry/runner"
require "telemetry/sinks/sink"
require "logger"
require "yaml"
require "core/forwardable_ext"

module Telemetry
  #spits out runner, sinks, loggers 
  #for the telemetry agent to use
  class Config
    extend SimpleForwardable

    attr_reader :runner, :sink

    delegate :run?, :run_basic?, :override?, :override=, :to => :runner

    def initialize(opts={})
      reset_error_logger!
      config_file = opts[:config_file]
      if config_file
        opts = YAML.load_file(config_file)
      end
      @runner = Runner.new(opts["enabled"])
      if @runner.enabled?
        begin
          @@error_logger ||= new_error_logger(opts["error_logger"])
          @sink = Sinks::Sink.new(opts["logger"], opts["http_endpoint"], self.error_logger, opts["in_memory"])
          @runner.attributes = {"sample_ratio" => opts["sample_ratio"], 
                                "host"         => opts["run_on_hosts"], 
                                "error_logger" => @@error_logger, 
                                "override"     => opts["override"] }
        rescue ErrorLogDeviceNotFound
          $stderr.puts "No Error Log Device. Switching runner off"
          @runner.off!
        rescue Errno::ENOENT
          $stderr.puts "Unable to create error logger at #{opts["error_logger"]} or log sink at #{opts["logger"]}. Switching runner off"
          @runner.off!
        rescue MissingSinkDeviceException
          $stderr.puts "No sink information supplied. \n" + 
          "You need a log file or a HTTP end point for your trace information to be written/sent somewhere\n" +
          "Switching runner off"
          @runner.off!
        end
      end
    end

    def error_logger
      self.class.error_logger
    end

    def self.error_logger
      @@error_logger
    end

    private
    def new_error_logger(logdevice)
      raise ErrorLogDeviceNotFound.new if !logdevice
      logger ||= ::Logger.new(logdevice)
      logger.formatter = ::Logger::Formatter.new
      logger
    end

    def reset_error_logger!
      @@error_logger = nil
    end
  end

  class ErrorLogDeviceNotFound  < Exception; end
end
