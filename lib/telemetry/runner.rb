require "socket"
require "telemetry/sampler"
require "telemetry/helpers/metadata"

module Telemetry
  class Runner
    attr_reader :sample, :sample_size, :host

    def initialize(enabled)
      @enabled = enabled

      if enabled?
        @sample, @sample_size = Sampler.parse
      end
    end

    def attributes=(opts={})
      if enabled?
        begin
          @sample, @sample_size = Sampler.parse(opts["sample_ratio"])
        rescue UnableToParseSampleRatioException
          off!
        end

        @host = opts["host"]
        @error_logger = opts["error_logger"]
        self.override = opts["override"]
      end
    end

    def override?
      return false if !enabled?

      if @override.is_a?(Proc)
        begin
          return !!@override.call
        rescue Exception => ex
          log_exception(ex)
          #don't assume override's result will be true
          #the next time its evaluated.
          #be conservative and trip the circuit - chances
          #are if the cache is down, there are much worse
          #problems in the making than the tracer running
          #override can always be flipped back on when the
          #cache/whatever recovers
          return false
        end
      else
        return !!@override
      end
    end

    #if override is true or false and flag is true or false
    # =>if override is different, change
    # if override is a proc and flag is a proc
    # change override period as the proc would have
    # to get evaluated anyway.
    def override=(flag)
      @override = flag if enabled?
    end

    def enabled?
      !!@enabled
    end

    def matching_host?
      enabled? && (@host.nil? ? true : !!(hostname =~ /#{@host}/))
    end

    def hostname
      Telemetry::Helpers::Metadata.hostname
    end

    def sample?
      enabled? && (rand(@sample_size) <= @sample)
    end

    def run?
      run_basic? && matching_host? && sample?
    end

    def run_basic?
      enabled? && override?
    end

    def off!
      @enabled = false
    end

    private
    def log_exception(ex)
      if @error_logger
        @error_logger.error "Error processing override value: #{ex.message}\n #{ex.backtrace.join("\n")}"
      end
    end
  end
end
