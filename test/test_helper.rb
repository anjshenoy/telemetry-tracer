require "minitest/spec"
require "minitest/autorun"

def restart_celluloid
  Celluloid.shutdown
  Celluloid.boot
end
