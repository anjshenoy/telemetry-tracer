require "telemetry/helpers/time_maker"

module Telemetry
  module Helpers
    module Timer
      def instrument(&block)
        start_time = time
        yield
        @instrumentation_time ||= 0
        @instrumentation_time += (time - start_time)
      end
    end
  end
end
