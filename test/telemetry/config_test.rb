require "test_helper"
require "./lib/telemetry/config"

module Telemetry

  describe "Config" do
    it "initializes a runner object" do
      @config = Config.new(opts)
      assert_equal true, @config.runner.run?
    end

    it "builds other dependencies only if the runner object decides tor run" do
      @config = Config.new(opts)
      assert_equal true, !@config.sink.nil?
      assert_equal true, !@config.error_logger.nil?

      @config = Config.new(opts.merge({"enabled" => false}))
      assert_nil @config.sink
      assert_nil @config.error_logger
    end

    it "configures everything from a yaml file if one is provided" do
      filepath = File.dirname(__FILE__) + "/config/tracer-test.yml"
      @config = Config.new({:config_file => filepath})
      assert_equal true, @config.runner.run?
      assert_equal true, !@config.sink.nil?
      assert_equal true, !@config.error_logger.nil?
    end

    private
    def opts
      {"enabled" => true,
       "sample" => {"number_of_requests" => 1,
                    "out_of" => 1},
       :log => {:filename => "tracer.log",
                :directory => "/tmp"}}
    end

  end
end
