require "spec_helper"
require "telemetry/runner"

module Telemetry
  describe Runner do
    before do
      MyAppCache.reset
    end

    let(:opts)   { {"sample" => {"number_of_requests" => 1, "out_of" => 1}} }
    let(:runner) { Runner.new(true) }

    it "has an enabled flag" do
      runner = Runner.new(true)
      expect(runner.enabled?).to be_true
    end

    it "can update its attributes" do
      runner.attributes = opts

      expect(runner.sample).to eq(1)
      expect(runner.sample_size).to eq(1)
    end

    it "has a sample flag" do
      runner.attributes = opts
      expect(runner.sample?).to be_true
    end

    it "sets up sampling rate and hosts only if its enabled" do
      runner = Runner.new(false)
      runner.attributes = {"sample" => {"number_of_requests" => 1, "out_of" => 1}}
      expect(runner.enabled?).to be_false
      expect(runner.sample?).to be_false
      expect(runner.matching_host?).to be_false
    end

    it "accepts a sampling rate out of a default of thousand" do
      runner.attributes = {"sample" => {"number_of_requests" => 2, "out_of" => 1024}}
      expect(runner.sample).to eq(2)
      expect(runner.sample_size).to be(1024)
    end

    it "sets a default sampling rate of 1 out of every 1024 requests if enabled" do
      expect(runner.sample).to eq(1)
      expect(runner.sample_size).to be(1024)
    end

    it "does not set up any sampling parameters if disabled" do
      runner = Runner.new(false)
      expect(runner.enabled?).to be_false
      expect(runner.sample).to be_nil
      expect(runner.sample_size).to be_nil
    end

    it "if a host regex is supplied, it runs it only on the hosts in question" do
      runner = Runner.new(true)
      runner.attributes = {"sample" => {}, "host" => "fubar-[1-3]"}
      expect(runner.matching_host?).to be_false
    end

    it "updates the host regex matcher only if enabled" do
      runner = Runner.new(false)
      runner.attributes = {"sample" => {}, "host" => "fubar-[1-3]"}
      expect(runner.host).to be_nil
    end

    it "runs it on all hosts if a host regex is not supplied" do
      expect(runner.matching_host?).to be_true
    end

    it "has an override flag which defaults to false unless explicitly enabled" do
      expect(runner.override?).to be_false

      runner.override = true
      expect(runner.override?).to be_true
    end


    it "changes the override flag only if enabled" do
      runner = Runner.new(false)

      runner.override = true
      expect(runner.override?).to be_false
    end

    it "stores a block of code as the override switch evaluated each time override? is called" do
      MyAppCache.tracer_enabled = false
      runner.override = Proc.new { MyAppCache.tracer_enabled }
      expect(runner.override?).to be_false

      #value changes on application cache
      MyAppCache.tracer_enabled = true
      expect(runner.override?).to be_true
    end

    it "does not return the value of override" do
      MyAppCache.tracer_enabled = 2
      runner.override = Proc.new { MyAppCache.tracer_enabled }

      expect(runner.override?).to eq(true)
    end

    it "can switch off the override at any time if enabled" do
      runner.override = true
      expect(runner.override?).to be_true

      runner.override = false
      expect(runner.override?).to be_false
    end

    it "can turn itself off at any time without touching the override flag" do
      runner.attributes = opts.merge({"override" => true})
      expect(runner.override?).to be_true
      expect(runner.run?).to be_true

      runner.off!
      expect(runner.run?).to be_false
    end

    it "returns false when override is evaluated if the corresponding proc raises an exception" do
      runner.override = Proc.new { raise "hell" }
      expect(runner.override?).to be_false
    end

  end
end
