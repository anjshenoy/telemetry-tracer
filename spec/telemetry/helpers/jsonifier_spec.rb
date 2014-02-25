require "spec_helper"
require "telemetry/helpers/jsonifier"

module Telemetry
  class DummyWithHash
    include Helpers::Jsonifier

    def to_hash
      {:a => "b"}
    end
  end

  class DummyWithoutHash
    include Helpers::Jsonifier
  end

  describe DummyWithHash do
    it "calling to_json returns the jsonified hash of the object" do
      hash = {:a => "b"}
      expect(DummyWithHash.new.to_json).to eq(hash.to_json)
    end
  end

  describe DummyWithoutHash do
    it "returns an empty json object if there is no hash method on the object" do
      expect(DummyWithoutHash.new.to_json).to eq("{}")
    end
  end
end
