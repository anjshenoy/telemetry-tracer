require "test_helper"
require "./lib/telemetry/annotation"

module Telemetry
  describe Annotation do

    it "stores the incoming list of key value pairs as is" do
      hash = {"foo" => "bar"}
      a = Annotation.new(hash)
      assert_equal hash, a.params
    end

    it "logs the current time" do
      a  = Annotation.new
      assert a.start_time < (Time.now.to_f * 1000000000).to_i

    end

  end
end
