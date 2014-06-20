require "socket"

module Telemetry
  module Helpers
    #capture metadata required for a trace
    class Metadata

      attr_reader :pid, :hostname

      def self.singleton
        @metadata ||= new
      end

      def self.pid
        singleton.pid
      end

      def self.hostname
        singleton.hostname
      end

      def self.to_hash
        @hash ||= {:pid => pid, :hostname => hostname}
      end

      private
      def initialize
        @pid = Process.pid
        @hostname = Socket.gethostname
      end
    end
  end
end
