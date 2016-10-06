# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Workflow::Rescue do
  let(:workflow_class) do
    Class.new(BasicWorkflowClass) do
      def on_runtime_error(exception)
        messages << exception
      end

      def cleanup
      end

      before_transition if: -> { messages.include?('Raise Error Please!') } do
        raise 'Big Error'
      end

      workflow do
        rescue_from Workflow::Errors::NoTransitionAllowed do |exception|
          messages << exception
        end

        rescue_from RuntimeError, with: :on_runtime_error

        state :initial do
          on :foo, to: :bar
        end
        state :bar
      end
    end
  end
  let(:workflow_object) { workflow_class.new }

  describe '#rescue_from' do
    it 'should handle the exception' do
      workflow_object.transition! :non_existent_event
      expect(workflow_object.messages.first).to be_kind_of(Workflow::Errors::NoTransitionAllowed)
    end

    it 'should properly call the instance method on exception' do
      workflow_object.messages << 'Raise Error Please!'
      workflow_object.transition! :foo
      expect(workflow_object.messages.last).to be_kind_of(RuntimeError)
    end
  end

  describe '#always' do
    describe 'With Method Name' do
      before do
        workflow_object.workflow_spec.always :cleanup
      end

      it 'should be called even if there is an error' do
        expect(workflow_object).to receive(:cleanup)
        workflow_object.transition! :non_existent_event
      end
    end
    describe 'With block' do
      before do
        workflow_object.workflow_spec.always do
          messages << 'Been Called'
        end
      end

      it 'Should call the block in the context of the workflow class object' do
        workflow_object.transition! :non_existent_event
        expect(workflow_object.messages).to include('Been Called')
      end
    end
  end
end
