require "spec_helper"
require "telemetry/sampler"

module Telemetry
  describe Sampler do

    it "converts a sample ratio to a sample_size and sample_pool" do
      sampler = Sampler.new(100)
      expect(sampler.sample_size).to eq(100)
      expect(sampler.sample_pool_size).to eq(100)
    end

    it "raises an UnableToParseSampleRatioException if the provided sample ratio is not a float or an int" do
      expect{Sampler.new("foo")}.to raise_error(Telemetry::UnableToParseSampleRatioException)
    end

    it "returns a sample_size of 100 if the sample_ratio is greater than or equal to 100" do
      sampler = Sampler.new(101)
      expect(sampler.sample_size).to eq(100)
      expect(sampler.sample_pool_size).to eq(100)

      sampler = Sampler.new(100)
      expect(sampler.sample_size).to eq(100)
      expect(sampler.sample_pool_size).to eq(100)
    end

    it "returns a default sample_size and pool of 1 and 100 respectively if no sample ratio is supplied" do
      sampler = Sampler.new
      expect(sampler.sample_size).to eq(1)
      expect(sampler.sample_pool_size).to eq(100)
    end

    it "returns a sample size and pool as a factor of 100" do
      sampler = Sampler.new(0.1)
      expect(sampler.sample_size).to eq(1)
      expect(sampler.sample_pool_size).to eq(1000)
    end

    it "returns a sample_size of 7 for a provided ratio of 7.24" do
      sampler = Sampler.new(7.24)
      expect(sampler.sample_size).to eq(7)
      expect(sampler.sample_pool_size).to eq(100)
    end

    it "returns a sample_size of 8 for a provided ratio of 7.56" do
      sampler = Sampler.new(7.56)
      expect(sampler.sample_size).to eq(8)
      expect(sampler.sample_pool_size).to eq(100)
    end

    it "has a convenience class method helper" do
      sample_size, sample_pool_size = Sampler.parse(nil)
      expect(sample_size).to eq(1)
      expect(sample_pool_size).to eq(100)
    end
  end 
end
