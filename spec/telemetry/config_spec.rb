require "spec_helper"
require "telemetry/config"
require "telemetry/sinks/sink"

module Telemetry
  describe Config do
    let(:config) { Config.new(tracer_opts) }

    it "initializes a runner object" do
      expect(config.runner.run?).to be_true
    end

    it "switches the runner off if there is no error log device" do
      opts = tracer_opts
      opts.delete("error_logger")
      expect(Config.new(opts).run?).to be_false
    end

    it "switches the runner off if there is no sink device" do
      opts = tracer_opts
      opts.delete("logger")
      expect(Config.new(opts).run?).to be_false
    end

    it "builds other dependencies only if the runner object decides tor run" do
      expect(config.sink).not_to be_nil
      expect(config.error_logger).not_to be_nil

      config = Config.new(tracer_opts.merge({"enabled" => false}))
      expect(config.sink).to be_nil
      expect(config.error_logger).to be_nil
    end

    it "configures everything from a yaml file if one is provided" do
      filepath = File.dirname(__FILE__) + "/config/tracer-test.yml"
      config = Config.new({:config_file => filepath})
      expect(config.run?).to be_false
      expect(config.sink).not_to be_nil
      expect(config.error_logger).not_to be_nil
    end

    it "can set up an in memory sink optionally" do
      opts = tracer_opts
      opts.delete("logger")
      config = Config.new(opts.merge!({"in_memory" => true}))

      expect(config.sink.traces).to eq([])
    end
  end
end
