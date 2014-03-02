require "spec_helper"
require "telemetry/annotation"

module Telemetry
  describe Annotation do
    let(:a) { Annotation.new(hash) }

    it "stores the incoming list of key value pairs as is" do
      expect(a.params).to eq(hash)
    end

    it "logs the current time" do
      expect(a.time).to be < (Time.now.to_f * 1000000000).to_i
    end

    it "comes with a to_hash method which lists its internals" do
      expect(a.to_hash["foo"]).to eq(hash["foo"])
      expect(a.to_hash[:logged_at]).not_to be_nil
    end

    it "logs the time to process if one is provided" do
      a = Annotation.new(hash, 1.123)
      expect(a.time_to_process).to eq(1.123)
    end

    private
    def hash
      {"foo" => "bar"}
    end
  end
end
