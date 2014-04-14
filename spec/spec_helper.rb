def restart_celluloid
  Celluloid.shutdown
  Celluloid.boot
end


def tracer_opts
  {"enabled" => true,
   "logger" => "/tmp/tracer.log",
   "error_logger" => "/tmp/tracer_errors.log",
   "sample" => {"number_of_requests" => 1, 
                "out_of" => 1}}
end


class Zephyr
  def perform
  end
end
