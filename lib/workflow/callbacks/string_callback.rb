module Workflow
  module Callbacks
    class StringCallback < Callback
      private

      def make_lambda(filter)
        l = eval "lambda { |value| #{filter} }"
        ->(target, value) { target.instance_exec(value, &l) }
      end
    end
  end
end
