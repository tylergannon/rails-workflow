# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Workflow::Callbacks::Callback do
  it 'Makes a callable thingy' do
    cb = described_class.build('true == false')
    expect(cb.callback).to be_kind_of(::Proc)
  end
end
