require "spec_helper"
require "telemetry/config"

module Telemetry
  describe Config do
    let(:opts) { {"enabled" => true,
                  "sample" => {"number_of_requests" => 1,
                               "out_of" => 1},
                  "logger" => "/tmp/tracer.log"}
              }
    let(:config) { Config.new(opts) }

    it "initializes a runner object" do
      expect(config.runner.run?).to be_true
    end

    it "builds other dependencies only if the runner object decides tor run" do
      expect(config.sink).not_to be_nil
      expect(config.error_logger).not_to be_nil

      config = Config.new(opts.merge({"enabled" => false}))
      expect(config.sink).to be_nil
      expect(config.error_logger).to be_nil
    end

    it "configures everything from a yaml file if one is provided" do
      filepath = File.dirname(__FILE__) + "/config/tracer-test.yml"
      config = Config.new({:config_file => filepath})
      expect(config.runner.run?).to be_true
      expect(config.sink).not_to be_nil
      expect(config.error_logger).not_to be_nil
    end
  end
end
