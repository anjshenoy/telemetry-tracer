require "socket"

module Telemetry
  class Runner
    attr_reader :opts, :sample, :sample_size

    def initialize(opts={})
      @opts = opts
      @sample, @sample_size = sample_and_size(opts[:sample])
      @host = opts[:run_on_hosts]
      @override = true
    end

    def override?
      @override
    end

    def override=(flag)
      @override = flag
    end

    def enabled?
      !!@opts[:enabled]
    end

    def sample_and_size(sample_opts={})
      if (sample_opts.nil? || sample_opts.empty?)
        [1, 1024]
      else
        [sample_opts[:number_of_requests], sample_opts[:out_of]]
        end
    end

    def matching_host?
      @host.nil? ? true : !!(Socket.gethostname =~ /#{@host}/)
    end

    def sample?
      rand(@sample_size) <= @sample
    end

    def run?
      enabled? && override? && matching_host? && sample?
    end
  end
end
