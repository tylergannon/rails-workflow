
# frozen_string_literal: true
module Workflow
  module Callbacks
    module TransitionCallbacks
      # @api private
      # A {Workflow::Callbacks::TransitionCallback} that wraps a callback proc.
      class ProcCaller < ::Workflow::Callbacks::TransitionCallback
        def normal_proc(target)
          transition_context = target.send :transition_context
          builder = NormalProcArgBuilder.new(transition_context, raw_proc)
          target.instance_exec target, *builder.args, &raw_proc
        end

        def around_proc(target, callbacks)
          transition_context = target.send :transition_context
          builder = AroundProcArgBuilder.new(transition_context, raw_proc)
          target.instance_exec target, callbacks, *builder.args, &raw_proc
        end

        class << self
          def build(callback_type, raw_proc, calling_class)
            return raw_proc if basic_callback?(raw_proc, callback_type)
            new(callback_type, raw_proc, calling_class)
          end

          private

          # Returns true if the method has arity zero.
          # Returns false if the method is defined and has non-zero arity.
          # Returns nil if the method has not been defined.
          def basic_callback?(method, callback_type)
            case method.arity
            when 0 then true
            when 1 then [:req, :opt].include?(method.parameters[0][0])
            when 2 then callback_type == :around
            else false
            end
          end
        end

        class NormalProcArgBuilder < MethodArgumentBuilder
          private

          def name_params
            super[1..-1] || []
          end
        end

        class AroundProcArgBuilder < MethodArgumentBuilder
          private

          def name_params
            super[2..-1] || []
          end
        end
      end
    end
  end
end
