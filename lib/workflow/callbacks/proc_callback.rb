module Workflow
  module Callbacks
    class ProcCallback < Callback
      private

      def make_lambda(filter)
        if filter.arity > 1
          return lambda do |target, _, &block|
            raise ArgumentError unless block
            target.instance_exec(target, block, &filter)
          end
        end

        if filter.arity <= 0
          ->(target, _) { target.instance_exec(&filter) }
        else
          ->(target, _) { target.instance_exec(target, &filter) }
        end
      end
    end
  end
end
