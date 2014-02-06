require "test_helper"
require "./lib/telemetry/annotation"

module Telemetry
  describe Annotation do

    def setup
      @a = Annotation.new(hash)
    end

    it "stores the incoming list of key value pairs as is" do
      assert_equal hash, @a.params
    end

    it "logs the current time" do
      assert @a.time < (Time.now.to_f * 1000000000).to_i
    end

    it "comes with a to_hash method which lists its internals" do
      assert_equal hash["foo"], @a.to_hash["foo"]
      assert_equal true, !@a.to_hash[:time].nil?
    end

    private
    def hash
      {"foo" => "bar"}
    end
  end
end
