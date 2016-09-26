# frozen_string_literal: true
module Workflow
  module Callbacks
    class StringCallback < Callback
      private

      def make_lambda(filter)
        ->(target, _value) { target.instance_eval(filter) }
      end
    end
  end
end
