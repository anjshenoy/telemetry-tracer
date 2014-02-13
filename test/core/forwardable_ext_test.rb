require "test_helper"
require "./lib/core/forwardable_ext"

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
      assert_equal dummy_association.boo, dummy.boo
    end

    it "delegates a list of methods to an associated object" do
      dummy_association = dummy.dummy_association

      [:foo, :bar].each do |method_name|
        assert_equal dummy_association.send(method_name), dummy.send(method_name)
      end
    end
  end
end
