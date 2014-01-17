module Telemetry
  module Helpers
    module TimeMaker
      def time
        (Time.now.to_f * 1000000000).to_i
      end
    end
  end
end
