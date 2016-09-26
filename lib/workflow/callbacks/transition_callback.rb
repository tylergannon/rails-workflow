
# frozen_string_literal: true
module Workflow
  module Callbacks
    # @api private
    # Wrapper object for proc and method callbacks, when that proc or method
    # is intended to receive arguments that were passed to the transition.
    # When the method/proc is to be called, a {MethodArgumentBuilder} determines
    # and generates the array of arguments to send to the method.
    # @see Workflow::Callbacks::TransitionCallbacks::MethodCaller
    # @see Workflow::Callbacks::TransitionCallbacks::ProcCaller
    class TransitionCallback
      attr_reader :callback_type, :raw_proc, :calling_class
      def initialize(callback_type, raw_proc, calling_class)
        @callback_type = callback_type
        @raw_proc      = raw_proc
        @calling_class = calling_class
      end

      def call(target, _value, &block)
        if around_callback?
          around_proc(target, block)
        else
          normal_proc(target)
        end
      end

      class << self
        def build(callback_type, raw_proc, calling_class)
          case raw_proc
          when ::Proc
            TransitionCallbacks::ProcCaller.build(callback_type, raw_proc, calling_class)
          when ::Symbol
            TransitionCallbacks::MethodCaller.build(callback_type, raw_proc, calling_class)
          else raw_proc
          end
        end
      end

      protected

      def around_callback?
        callback_type == :around
      end

      # Builds arguments appropriate for calling the wrapped proc or method.
      class MethodArgumentBuilder
        attr_reader :transition_context, :method, :event, :from, :to, :attributes, :event_args
        attr_reader :args
        def initialize(transition_context, method)
          @transition_context = transition_context
          @method = method
          @from, @to, @event, @event_args, @attributes = transition_context.values
          build_args
        end

        def build_args
          @args = name_arguments + rest_arguments
          kwargs = keyword_arguments.merge(keyrest_arguments)
          @args << kwargs unless kwargs.empty?
        end

        def name_arguments
          name_params.map do |name|
            case name
            when :to then to
            when :from then from
            when :event then event
            else (attributes.delete(name) || event_args.shift)
            end
          end
        end

        def rest_arguments
          if rest_param
            event_args
          else
            []
          end
        end

        def keyword_arguments
          kw_params.map do |name|
            [name, attributes.delete(name)]
          end.to_h
        end

        def keyrest_arguments
          if keyrest_param
            attributes
          else
            {}
          end
        end

        def name_params
          params_by_type :opt, :req
        end

        def kw_params
          params_by_type :keyreq, :keyopt
        end

        def keyrest_param
          params_by_type(:keyrest).first
        end

        def rest_param
          params_by_type(:rest).first
        end

        def params_by_type(*types)
          parameters.select do |type, _name|
            types.include? type
          end.map(&:last)
        end

        # Parameter definition for the object.  See UnboundMethod#parameters
        #
        # @return [Array] Parameters
        def parameters
          method.parameters
        end
      end
    end
  end
end
