module Telemetry
  class UnableToParseSampleRatioException < Exception; end

  class Sampler

    #sample one out of every 100 requests by default
    DEFAULT_SAMPLE_RATIO = 1

    attr_reader :sample_size, :sample_pool_size

    def initialize(sample_ratio = nil)
      sample_ratio ||= DEFAULT_SAMPLE_RATIO
      @sample_pool_size = 100
      if sample_ratio.is_a?(Integer)
        @sample_size = sample_ratio >= 100 ? 100 : sample_ratio
      elsif sample_ratio.is_a?(Float)
        until (sample_ratio >= 1) do
          sample_ratio *= 10
          @sample_pool_size *= 10
        end
        @sample_size = sample_ratio.round
      else
        raise UnableToParseSampleRatioException
      end

    end


    def self.parse(sample_ratio = nil)
      sampler = Sampler.new(sample_ratio)
      [sampler.sample_size, sampler.sample_pool_size]
    end
  end
end
