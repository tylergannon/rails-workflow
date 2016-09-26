# frozen_string_literal: true
require 'spec_helper'

RSpec.describe 'Callback Method Parameters' do
  let(:workflow_class) do
    klass = Class.new do
      include Workflow
      attr_accessor :message

      before_transition :start1_normal_arg, only: :start1
      before_transition :start2_normal_arg, only: :start2
      before_transition :start3_normal_arg, only: :start3
      around_transition :start4_normal_arg, only: :start4

      def start1_normal_arg(foo)
        self.message = foo
      end

      def start2_normal_arg(foo, bar)
        self.message = [bar, foo]
      end

      def start3_normal_arg(foo, bar, *args, cool:, **attributes)
        self.message = [foo, bar, args, cool, attributes]
      end

      def start4_normal_arg(foo, bar, *args, cool:, **attributes)
        self.message = [foo, bar, args, cool, attributes]
        yield
      end

      workflow do
        state :initial do
          on :start1, to: :started
          on :start2, to: :started
          on :start3, to: :started
          on :start4, to: :started
        end
        state :started
      end
    end
  end
  subject { workflow_class.new }

  describe 'One Parameter' do
    it 'gets the message' do
      subject.start1! :tight
      expect(subject.message).to eq :tight
    end
  end

  describe 'Two Parameter' do
    it 'gets the message' do
      subject.start2! :tight, :nice
      expect(subject.message).to eq [:nice, :tight]
    end
  end

  describe 'Three Parameter' do
    it 'gets the message' do
      subject.start3! :tight, :nice, :word, :up, dope: :sauce, cool: :bar, right: :now
      expect(subject.message).to eq [:tight, :nice, [:word, :up], :bar, { dope: :sauce, right: :now }]
    end
  end

  describe 'Around Transition' do
    it 'gets the message' do
      subject.start4! :tight, :nice, :word, :up, dope: :sauce, cool: :bar, right: :now
      expect(subject.message).to eq [:tight, :nice, [:word, :up], :bar, { dope: :sauce, right: :now }]
      expect(subject).to be_started
    end
  end
end
