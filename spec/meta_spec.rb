# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Workflow::State do
  let(:workflow_class) do
    new_workflow_class do
      state :foo, nice: { bar: :baz } do
        on :do_something, cool: :bar, to: :foo
      end
      state :foo
    end
  end

  it 'should get extra accessors for the metadata defined' do
    state = workflow_class.new.current_state
    expect(state.nice).to eq(bar: :baz)
    event = state.events.first
    expect(event.cool).to eq :bar
  end
end
