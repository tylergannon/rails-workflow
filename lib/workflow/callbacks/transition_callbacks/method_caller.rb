# frozen_string_literal: true
module Workflow
  module Callbacks
    module TransitionCallbacks
      # @api private
      # A {Workflow::Callbacks::TransitionCallback} that calls an instance method
      # With arity != 0.
      class MethodCaller < ::Workflow::Callbacks::TransitionCallback
        attr_reader :calling_class

        def normal_proc(target)
          transition_context = target.send :transition_context
          method = target.method(raw_proc)
          builder = MethodArgumentBuilder.new(transition_context, method)
          target.instance_exec(*builder.args, &method)
        end

        def around_proc(target, callbacks)
          transition_context = target.send :transition_context
          method = target.method(raw_proc)
          builder = MethodArgumentBuilder.new(transition_context, method)
          target.send raw_proc, *builder.args, &callbacks
        end

        class << self
          def build(callback_type, raw_proc, calling_class)
            return raw_proc if zero_arity_method?(raw_proc, calling_class)
            new(callback_type, raw_proc, calling_class)
          end

          private

          # Returns true if the method has arity zero.
          # Returns false if the method is defined and has non-zero arity.
          # Returns nil if the method has not been defined.
          def zero_arity_method?(method, calling_class)
            return false unless calling_class.instance_methods.include?(method)
            method = calling_class.instance_method(method)
            method.arity.zero?
          end
        end

        private

        # @return [UnboundMethod] Method representation from class
        #                         {#calling_class}, named by {#raw_proc}
        def callback_method
          @meth ||= calling_class.instance_method(raw_proc)
        end
      end
    end
  end
end
