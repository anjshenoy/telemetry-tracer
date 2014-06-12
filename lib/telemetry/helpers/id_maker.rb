module Telemetry
  module Helpers

    module IdMaker
      TWO_POWER_THIRTY_TWO = 2**32
      TWO_POWER_SIXTY_FOUR = 2**64

      srand

      def generate_id
        (self.class == Span) ? rand(1..TWO_POWER_THIRTY_TWO) : rand(1..TWO_POWER_SIXTY_FOUR)
      end
    end
  end
end
