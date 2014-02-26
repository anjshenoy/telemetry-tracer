require "yajl"

module Telemetry
  module Helpers
    module Jsonifier
      def to_json
        hash = respond_to?(:to_hash) ? to_hash : {}
        Yajl::Encoder.encode(hash)
      end
    end
  end
end
