# frozen_string_literal: true
module Workflow
  module Callbacks
    module TransitionCallbacks
      # A {Workflow::Callbacks::TransitionCallback} that wraps an instance method
      # With arity != 0.
      # Because the wrapped method may not have been defined at the time the callback
      # is defined, the string representing the method call is built at runtime
      # rather than at compile time.
      class MethodWrapper < ::Workflow::Callbacks::TransitionCallback
        attr_reader :calling_class

        # Builds a proc object that will correctly call the {#raw_proc}
        # by inspecting its parameters and pulling arguments from the {Workflow::TransitionContext}
        # object for the transition.
        # Given an overloaded `==` operator so for {Workflow#skip_before_transition} and other
        # `skip_transition` calls.
        # @return [Type] description of returned object
        def wrapper
          cb_object = self
          proc_string = build_proc(<<-EOF)
            arguments = [
              cb_object.send(:raw_proc).inspect,
              cb_object.send(:name_arguments_string),
              cb_object.send(:rest_param_string),
              cb_object.send(:kw_arguments_string),
              cb_object.send(:keyrest_string),
              cb_object.send(:procedure_string)].compact.join(', ')
            target.instance_eval("send(\#{arguments})")
          EOF
          wrapper_proc = eval(proc_string)
          wrapper_proc.instance_exec(raw_proc, &OVERLOAD_EQUALITY_OPERATOR_PROC)
          wrapper_proc
        end

        private

        # A that is instanced_exec'd on a new proc object within {#wrapper}
        #
        # Enables comparison of two wrapper procs to determine if they wrap the same
        # Method.
        OVERLOAD_EQUALITY_OPERATOR_PROC = proc do |_method_name|
          def method_name
            method_name
          end

          # Equality operator overload.
          # If other is a {Symbol}, matches this object against {#method_name} defined above.
          # If other is a {Proc}:
          # * If it responds to {#method_name}, matches the method names of the two objects.
          # * Otherwise false
          #
          # @param [Symbol] other A method name to compare against.
          # @param [Proc] other A proc to compare against.
          # @return [Boolean] Whether the two should be considered equivalent
          def ==(other)
            case other
            when ::Proc
              if other.respond_to?(:raw_proc)
                method_name == other.method_name
              else
                false
              end
            when ::Symbol
              method_name == other
            else
              false
            end
          end
        end

        def name_arguments_string
          return unless name_params.any?

          name_params.map do |name|
            "name_proc.call(:#{name})"
          end.join(', ')
        end

        def procedure_string
          '&callbacks' if around_callback?
        end

        # @return [UnboundMethod] Method representation from class
        #                         {#calling_class}, named by {#raw_proc}
        def callback_method
          @meth ||= calling_class.instance_method(raw_proc)
        end

        # Parameter definition for the object.  See {UnboundMethod#parameters}
        #
        # @return [Array] Parameters
        def parameters
          callback_method.parameters
        end

        # @return [Fixnum] Arity of the callback method
        def arity
          callback_method.arity
        end
      end
    end
  end
end
