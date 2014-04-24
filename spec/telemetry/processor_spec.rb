require "spec_helper"
require "telemetry/processor"

module Telemetry
  describe Processor do

    it "takes a name and a block of code to be evaluated" do
      processor = Processor.new("foo") do
        2*2
      end

      expect(processor.name).to eq("foo")
      expect(processor.future.class).to eq(Celluloid::Future)
    end

    it "evaluates the block of code and returns the result as a key value pair" do
      processor = Processor.new("foo") do
        2*2
      end
      result = {"foo" =>  4}
      expect(processor.run).to include(result)
    end

    it "sends back the result as is by default even if its nil or empty" do
      processor = Processor.new("foo") do
        ""
      end

      expect(processor.run).to include({ "foo" => ""})
      processor = Processor.new("foo") do
        nil
      end

      expect(processor.run).to include({ "foo" => nil})
    end

    it "sends back an nil result if the ignore if blank option is set to true" do
      processor = Processor.new("foo", true) do
        ""
      end

      expect(processor.run).to be_nil

      processor = Processor.new("foo", false) do
        nil
      end

      expect(processor.run).to include({ "foo" => nil})
    end

    it "stores the time taken to evaluate the processed block" do
      processor =  Processor.new("foo") do
        2*2
      end

      expect(processor.run[:instrumentation_time]).to be > 0
    end

    it "logs the value as 'processing_error' if an exception is raised when processing the value" do
      processor = Processor.new("foo") do
        raise "Hello"
      end

      hash = {"foo" => "processing_error"}
      expect(processor.run).to include(hash)
    end

    it "records the exception if one was raised when processing the value" do
      processor = Processor.new("foo") do
        raise "Hello"
      end

      expect(processor.run[:exception]).to start_with("RuntimeError: Hello")
    end

  end
end
