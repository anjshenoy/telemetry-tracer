require "minitest/spec"
require "minitest/autorun"

$LOAD_PATH << File.dirname(File.expand_path(__FILE__)) + "/../lib/"

def restart_celluloid
  Celluloid.shutdown
  Celluloid.boot
end
