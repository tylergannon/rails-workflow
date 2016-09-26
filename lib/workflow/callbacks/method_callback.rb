module Workflow
  module Callbacks
    class MethodCallback < Callback

      private
      
      def make_lambda(filter)
        ->(target, _, &blk) { target.send filter, &blk }
      end
    end
  end
end
