module Telemetry
  module Helpers
    module IdMaker
      def generate_id
        (self.class == Span) ? rand(1..2**32) : rand(1..2**64)
      end
    end
  end
end
