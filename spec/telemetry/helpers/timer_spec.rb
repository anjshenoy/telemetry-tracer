require "spec_helper"
require "telemetry/helpers/timer"

module Telemetry
  class Dummy
    include Helpers::Timer

    attr_reader :instrumentation_time

    def foo
      instrument do
        2*2
      end
    end
  end

  describe Dummy do
    it "logs the instrumentation time" do
      dummy = Dummy.new
      expect(dummy.instrumentation_time).to be_nil
      dummy.foo
      expect(dummy.instrumentation_time).to be > 0
    end
  end

end

