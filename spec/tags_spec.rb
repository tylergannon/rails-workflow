# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Workflow::State do
  describe 'Assigning Tags To States' do
    let(:workflow_class) do
      new_workflow_class do
        state :new, tags: [:cool, :bar] do
          on :complete, to: :interim, tags: :feedback
        end
        state :interim do
          on :complete, to: :completed, tags: [:foo, :bar]
        end
        state :completed, tags: :baz
      end
    end

    subject { workflow_class.new }

    it 'knows its state is initial' do
      expect(subject.current_state).to be_initial
    end

    it "has tag helpers on its events" do
      expect(subject.current_state.events.first).to be_feedback
    end

    it 'responds yes to tags' do
      expect(subject.current_state).to be_cool
      expect(subject.current_state).to be_bar
    end

    it "responds no if doesn't have tag" do
      expect(subject.current_state).not_to be_baz
    end

    it 'knows its state is not terminal' do
      expect(subject.current_state).not_to be_terminal
    end

    describe "In the interim state" do
      before do
        subject.complete!
      end
      it "has tag helpers on its events" do
        expect(subject.current_state.events.first).not_to be_feedback
        expect(subject.current_state.events.first).to be_bar
        expect(subject.current_state.events.first).to be_foo
      end
    end

    describe 'In the terminal state' do
      before do
        subject.complete!
        subject.complete!
      end

      it 'responds truthily to tags' do
        expect(subject.current_state).to be_baz
      end

      it "responds false if doesn't have tags" do
        expect(subject.current_state).not_to be_cool
        expect(subject.current_state).not_to be_bar
      end

      it 'knows that it is terminal' do
        expect(subject.current_state).to be_terminal
      end
    end
  end
end
