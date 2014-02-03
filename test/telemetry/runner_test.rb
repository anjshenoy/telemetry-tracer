require "test_helper"
require "./lib/telemetry/runner"

module Telemetry
  describe Runner do
    it "has an enabled flag" do
      runner = Runner.new({:enabled => true})
      assert_equal true, runner.enabled?
    end

    it "accepts a sampling rate out of a default of thousand" do
      runner = Runner.new({:sample => {:number_of_requests => 2, :out_of => 1024}})
      assert_equal 2, runner.sample
      assert_equal 1024, runner.sample_size
    end

    it "sets a default sampling rate of 1 out of every 1000 requests" do
      runner = Runner.new
      assert_equal 1, runner.sample
      assert_equal 1024, runner.sample_size
    end

    it "has a sample flag" do
      runner = Runner.new({:sample => {:number_of_requests => 1, :out_of => 1}})
      assert_equal true, runner.sample?
    end

    it "if a host regex is supplied, it runs it only on the hosts in question" do
      runner = Runner.new({:run_on_hosts => "fubar-[1-3]"})
      assert_equal false, runner.matching_host?
    end

    it "runs it on all hosts if a host regex is not supplied" do
      assert_equal true, Runner.new.matching_host?
    end

    it "has an override flag which defaults to true" do
      assert_equal true, Runner.new.override?
    end

    it "can switch of the override at any time" do
      runner = Runner.new
      assert_equal true, runner.override?
      runner.override = false
      assert_equal false, runner.override?
    end

    it "runs only if the host matches the current host, if its enabled and if the override switch is true" do
      sample_opts = {:sample => {:number_of_requests => 1, :out_of => 1}}
      opts = {:enabled => true}.merge(sample_opts)

      runner = Runner.new(opts)
      assert_equal true, runner.run?
      runner.override = false
      assert_equal false, runner.run?

      assert_equal false, Runner.new(opts.merge({:enabled => false})).run?

      sample_opts = {:sample => {:number_of_requests => 1, :out_of => 1024}}
      assert_equal false, Runner.new(opts.merge(sample_opts)).run?
    end
  end
end
