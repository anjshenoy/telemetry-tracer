require "json"

module Telemetry
  module Helpers
    module Jsonifier
      def to_json
        hash = respond_to?(:to_hash) ? to_hash : {}
        hash.to_json
      end
    end
  end
end
