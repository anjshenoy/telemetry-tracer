require "minitest/spec"
require "minitest/autorun"

$LOAD_PATH << File.dirname(File.expand_path(__FILE__)) + "/../lib/"

def restart_celluloid
  Celluloid.shutdown
  Celluloid.boot
end


def tracer_opts
  {"enabled" => true,
   "logger" => "/tmp/tracer.log",
   "sample" => {"number_of_requests" => 1, 
                "out_of" => 1}}
end

def default_tracer(override_opts={})
  Telemetry::Tracer.find_or_create(tracer_opts.merge!(override_opts))
end
