require "simplecov"
SimpleCov.start

def restart_celluloid
  Celluloid.shutdown
  Celluloid.boot
end


def tracer_opts
  {"enabled" => true,
   "logger" => "/tmp/tracer.log",
   "error_logger" => "/tmp/tracer_errors.log",
   "sample_ratio" => 100,
   "override" => true }
end

def in_memory_tracer_opts
  {"enabled" => true,
   "in_memory" => true,
   "override" => true,
   "error_logger" => "/tmp/tracer_errors.log",
   "sample_ratio" => 100}
end

module Telemetry
  class Tracer
    #reset the tracer for testing purposes
    class << self
      def reset_with_config
        Tracer.reset
        Tracer.instance_variable_set("@config", nil)
      end
    end
  end
end


class Zephyr
  def perform
  end
end

class MyAppCache
  def self.tracer_enabled=(value)
    @@value = value
  end

  def self.tracer_enabled
    @@value
  end

  def self.reset
    @@value = nil
  end
end

