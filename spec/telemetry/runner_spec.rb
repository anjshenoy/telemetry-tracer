require "spec_helper"
require "telemetry/runner"

module Telemetry
  describe Runner do
    before do
      MyAppCache.reset
    end

    let(:runner) { Runner.new(true, {"sample" => {"number_of_requests" => 1, "out_of" => 1}}) }

    it "has an enabled flag" do
      runner = Runner.new(true)
      expect(runner.enabled?).to be_true
    end

    it "has a sample flag" do
      expect(runner.sample?).to be_true
    end

    it "sets up sampling rate and hosts only if its enabled" do
      runner = Runner.new(false, {"sample" => {"number_of_requests" => 1, "out_of" => 1}})
      expect(runner.enabled?).to be_false
      expect(runner.sample?).to be_false
      expect(runner.matching_host?).to be_false
    end

    it "accepts a sampling rate out of a default of thousand" do
      runner = Runner.new(true, {"sample" => {"number_of_requests" => 2, "out_of" => 1024}})
      expect(runner.sample).to eq(2)
      expect(runner.sample_size).to be(1024)
    end

    it "sets a default sampling rate of 1 out of every 1024 requests" do
      runner = Runner.new(true)
      expect(runner.sample).to eq(1)
      expect(runner.sample_size).to be(1024)
    end

    it "if a host regex is supplied, it runs it only on the hosts in question" do
      runner = Runner.new(true, {}, "fubar-[1-3]")
      expect(runner.matching_host?).to be_false
    end

    it "runs it on all hosts if a host regex is not supplied" do
      expect(runner.matching_host?).to be_true
    end

    it "has an override flag which defaults to true" do
      expect(runner.override?).to be_true
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

    it "accepts override as a Proc when initialized" do
      MyAppCache.tracer_enabled = false
      runner = Runner.new(true, 
                          {"sample" => {"number_of_requests" => 1, "out_of" => 1}}, 
                          "foo.xyz.com",
                          Proc.new { MyAppCache.tracer_enabled })


      expect(runner.override?).to be_false
    end

    it "can switch off the override at any time" do
      expect(runner.override?).to be_true

      runner.override = false
      expect(runner.override?).to be_false
    end

    it "retains the current value of the override flag if it is set to nil" do
      expect(runner.override?).to be_true

      runner.override = nil
      expect(runner.override?).to be_true
    end

    it "can turn itself off at any time without touching the override flag" do
      expect(runner.run?).to be_true
      expect(runner.override?).to be_true

      runner.off!
      expect(runner.override?).to be_true
      expect(runner.run?).to be_false
    end

    it "checks if the current override state is different from the supplied value" do
      runner.override = false
      expect(runner.override_different_from?(true)).to be_true

      MyAppCache.tracer_enabled = false
      expect(runner.override_different_from?(Proc.new{ MyAppCache.tracer_enabled })).to be_false
    end
  end
end
