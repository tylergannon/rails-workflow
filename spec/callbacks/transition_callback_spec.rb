require 'spec_helper'

RSpec.describe Workflow::Callbacks::TransitionCallback do
  let(:workflow_class) do
    Class.new do
      include Workflow
      workflow do
        state :foo do
          on :bar, to: :baz
        end
        state :baz
      end
    end
  end
  describe "Method-Type Callback" do
    subject {
      described_class.build_wrapper(:before, :zero_arity, workflow_class)
    }
    describe "When the method has zero-arity" do
      describe "when the method has already been defined when the callback is defined" do
        before do
          workflow_class.class_eval do
            def zero_arity
            end
          end
        end
        it "should return the method name" do
          expect(subject).to eq :zero_arity
        end
      end

      describe "when the method was not yet defined when the callback is defined" do
        it "should return the method name" do
          expect(subject).to be_kind_of Workflow::Callbacks::TransitionCallback
        end
      end
    end
  end
end
