# frozen_string_literal: true
require 'spec_helper'

RSpec.describe 'Advanced Examples' do
  class AdvancedExample
    include Workflow
    workflow do
      define_revert_events!
      state :new do
        on :submit, to: :awaiting_review
      end
      state :awaiting_review do
        on :review, to: :being_reviewed
      end
      state :being_reviewed do
        on :accept, to: :accepted
        on :reject, to: :rejected
      end
      state :accepted do
      end
      state :rejected do
      end
    end
  end

  describe '#63 Undoing Events' do
    subject { AdvancedExample.new }
    it { is_expected.to be_new }
    it 'should be able to progress as normal' do
      expect do
        subject.submit!
      end.to change {
        subject.current_state.name
      }.from(:new).to(:awaiting_review)
    end

    describe 'Reversion events' do
      before do
        subject.submit!
      end
      it 'should have an additional event for reverting the submit' do
        expect(subject.current_state.events.map(&:name)).to include(:revert_submit)
        expect(subject.current_state.events.map(&:name)).to include(:review)
      end

      it 'should be able to revert the submit' do
        expect do
          subject.revert_submit!
        end.to change {
          subject.current_state.name
        }.from(:awaiting_review).to(:new)
      end
    end
  end

  describe '#92 - Load ad-hoc workflow specification' do
    let(:adhoc_class) do
      new_workflow_class do
        state :one do
          on :dynamic_transition, to: :one_a
        end
        state :one_a
      end
    end

    subject { adhoc_class.new }

    it 'should be able to load and run dynamically generated state transitions' do
      expect do
        subject.dynamic_transition!(1)
      end.to change {
        subject.current_state.name
      }.from(:one).to(:one_a)
    end

    it 'should not have a revert event' do
      states = adhoc_class.workflow_spec.unique_event_names.map(&:to_s)
      expect(states.select { |t| t =~ /^revert/ }).to be_empty
    end

    describe 'unless you want revert events' do
      let(:adhoc_class) do
        new_workflow_class do
          define_revert_events!
          state :one do
            on :dynamic_transition, to: :one_a
          end
          state :one_a
        end
      end

      it 'should have revert events' do
        states = adhoc_class.workflow_spec.unique_event_names.map(&:to_s)
        expect(states.select { |t| t =~ /^revert/ }).not_to be_empty
      end
    end
  end
end
