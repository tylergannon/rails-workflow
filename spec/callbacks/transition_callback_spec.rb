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
  end
end
