require "test_helper"
require "./lib/telemetry/runner"

module Telemetry
  describe Runner do
    let(:runner) { Runner.new(true, {"sample" => {"number_of_requests" => 1, "out_of" => 1}}) }

    it "has an enabled flag" do
      runner = Runner.new(true)
      assert_equal true, runner.enabled?
    end

    it "sets up sampling rate and hosts only if its enabled" do
      runner = Runner.new(false, {"sample" => {"number_of_requests" => 1, "out_of" => 1}})
      assert_equal false, runner.override?
      assert_equal false, runner.sample?
      assert_equal false, runner.matching_host?
    end

    it "accepts a sampling rate out of a default of thousand" do
      runner = Runner.new(true, {"sample" => {"number_of_requests" => 2, "out_of" => 1024}})
      assert_equal 2, runner.sample
      assert_equal 1024, runner.sample_size
    end

    it "sets a default sampling rate of 1 out of every 1024 requests" do
      runner = Runner.new(true)
      assert_equal 1, runner.sample
      assert_equal 1024, runner.sample_size
    end

    it "has a sample flag" do
      assert_equal true, runner.sample?
    end

    it "if a host regex is supplied, it runs it only on the hosts in question" do
      runner = Runner.new(true, {}, "fubar-[1-3]")
      assert_equal false, runner.matching_host?
    end

    it "runs it on all hosts if a host regex is not supplied" do
      assert_equal true, runner.matching_host?
    end

    it "has an override flag which defaults to true" do
      assert_equal true, runner.override?
    end

    it "can switch off the override at any time" do
      assert_equal true, runner.override?
      runner.override = false
      assert_equal false, runner.override?
    end
  end
end
