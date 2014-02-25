require "test_helper"
require "./lib/telemetry/helpers/jsonifier"

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
      assert_equal hash.to_json, DummyWithHash.new.to_json
    end
  end

  describe DummyWithoutHash do
    it "returns an empty json object if there is no hash method on the object" do
      assert_equal "{}", DummyWithoutHash.new.to_json
    end
  end
end
