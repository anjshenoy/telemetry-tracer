require "spec_helper"
require "core/forwardable_ext"

class Dummy
  extend SimpleForwardable

  attr_reader :dummy_association
  delegate :boo, :to => :dummy_association
  delegate :boo, :foo, :bar, :to => :dummy_association

  def initialize
    @dummy_association = DummyAssociation.new
  end
end

class DummyAssociation
  def boo
    "something"
  end

  def foo
    "foo"
  end

  def bar
    "bar"
  end
end

module Telemetry
  describe SimpleForwardable do
    let(:dummy) {Dummy.new}

    it "delegates a method to an associated object" do
      dummy_association = dummy.dummy_association
      expect(dummy.boo).to eq(dummy_association.boo)
    end

    it "delegates a list of methods to an associated object" do
      dummy_association = dummy.dummy_association

      [:foo, :bar].each do |method_name|
        expect(dummy.send(method_name)).to eq(dummy_association.send(method_name))
      end
    end
  end
end
