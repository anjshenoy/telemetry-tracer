require "socket"

module Telemetry
  class Runner
    attr_reader :sample, :sample_size

    def initialize(*args)
      @enabled, sample, @host, @override = args
      if enabled?
        @sample, @sample_size = sample_and_size(sample)
        @override ||= true
      end
    end

    def override?
      if @override == true || @override == false
        @override
      elsif @override.is_a?(Proc)
        !!(@override.call)
      else
        #break circuit because we don't know how to 
        #evaluate override
        false
      end
    end

    def override_different_from?(flag)
      if flag.is_a?(Proc)
        override? != flag.call
      else
        override? != flag
      end
    end

    def override=(flag)
      @override = flag if !flag.nil?
    end

    def enabled?
      !!@enabled
    end

    def sample_and_size(sample_opts={})
      if (sample_opts.nil? || sample_opts.empty?)
        [1, 1024]
      else
        sample_opts = sample_opts["sample"]
        [sample_opts["number_of_requests"], sample_opts["out_of"]]
      end
    end

    def matching_host?
      enabled? && (@host.nil? ? true : !!(Socket.gethostname =~ /#{@host}/))
    end

    def sample?
      enabled? && (rand(@sample_size) <= @sample)
    end

    def run?
      enabled? && override? && matching_host? && sample?
    end

    def off!
      @enabled = false
    end
  end
end
