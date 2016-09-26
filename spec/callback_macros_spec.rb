# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Workflow::Callbacks do
  let(:workflow_class) do
    new_workflow_class do
      state :initial do
        on :process, to: :processing
        on :different_process, to: :processing
      end
      state :processing do
        on :finish, to: :done
      end
      state :done
    end
  end

  let(:model) do
    workflow_class.new
  end

  before do
    workflow_class.class_eval do
      attr_accessor :messages
      def initialize
        self.messages = []
      end

      before_transition do
        raise 'Problem!'
      end
    end
  end

  describe '#ensure_after_transitions' do
    def run_transition
      expect do
        model.process!
      end.to raise_error(RuntimeError, 'Problem!')
    end
    it 'Always calls the block' do
      workflow_class.class_eval do
        ensure_after_transitions do
          messages << :foo
        end
      end
      run_transition
      expect(model.messages).to include(:foo)
    end

    it 'Always calls the expression' do
      workflow_class.class_eval do
        ensure_after_transitions 'self.messages << :foo'
      end
      run_transition
      expect(model.messages).to include(:foo)
    end

    it 'Always calls the expression and the block' do
      workflow_class.class_eval do
        ensure_after_transitions 'self.messages << :foo' do
          messages << :foo
        end
      end
      run_transition
      expect(model.messages).to eq [:foo, :foo]
    end
  end

  describe '#on_error' do
    describe 'with conditions' do
      it 'Only catches the error on the given condition' do
        workflow_class.class_eval do
          on_error RuntimeError, if: 'self.messages.empty?' do |_ex|
            messages << :foo
          end
        end

        expect do
          model.process!
        end.not_to raise_error
        expect(model.messages).to include(:foo)
        expect do
          model.process!
        end.to raise_error(RuntimeError, 'Problem!')
        expect(model.messages.length).to eq 1
      end

      it 'Only runs the error catching callback on the given event' do
        workflow_class.class_eval do
          on_error RuntimeError, only: :process do |_ex|
            messages << :foo
          end
        end
        3.times do
          expect do
            model.process!
          end.not_to raise_error
        end

        expect do
          model.different_process!
        end.to raise_error(RuntimeError, 'Problem!')
      end
    end
    it 'will raise an error if the error is not caught' do
      expect do
        model.process!
      end.to raise_error(RuntimeError, 'Problem!')
    end

    it 'Catches the error and executes the block' do
      workflow_class.class_eval do
        on_error RuntimeError do |_ex|
          messages << :foo
        end
      end

      expect do
        model.process!
      end.not_to raise_error
      expect(model.messages).to include(:foo)
    end

    it 'Catches the error and runs the :rescue expression' do
      workflow_class.class_eval do
        on_error RuntimeError, rescue: 'self.messages << :foo'
      end

      expect do
        model.process!
      end.not_to raise_error
      expect(model.messages).to include(:foo)
    end

    it 'Catches the error and runs the :ensure expression' do
      workflow_class.class_eval do
        on_error RuntimeError, ensure: 'self.messages << :foo'
      end

      expect do
        model.process!
      end.not_to raise_error
      expect(model.messages).to include(:foo)
    end

    it 'Does all three' do
      workflow_class.class_eval do
        on_error RuntimeError, rescue: 'self.messages << :foo', ensure: 'self.messages << :foo' do |_ex|
          messages << :foo
        end
      end

      expect do
        model.process!
      end.not_to raise_error
      expect(model.messages).to eq [:foo, :foo, :foo]
    end
  end
end
