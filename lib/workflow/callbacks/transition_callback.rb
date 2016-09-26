
# frozen_string_literal: true
module Workflow
  module Callbacks
    class TransitionCallback
      attr_reader :callback_type, :raw_proc, :calling_class
      def initialize(callback_type, raw_proc, calling_class)
        @callback_type = callback_type
        @raw_proc      = raw_proc
        @calling_class = calling_class
      end

      class << self
        def build_wrapper(callback_type, raw_proc, calling_class)
          if raw_proc.is_a? ::Proc
            TransitionCallbacks::ProcWrapper.new(callback_type, raw_proc, calling_class)
          elsif raw_proc.is_a? ::Symbol
            if zero_arity_method?(raw_proc, calling_class)
              raw_proc
            else
              TransitionCallbacks::MethodWrapper.new(callback_type, raw_proc, calling_class)
            end
          else
            raw_proc
          end
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

      def wrapper
        raise NotImplementedError, 'Abstract Method Called'
      end

      protected

      def build_proc(proc_body)
        <<-EOF
          Proc.new do |target#{', callbacks' if around_callback?}|
            from, to, event, event_args, attributes = transition_context.values
            name_proc  = Proc.new {|name|
              case name
              when :to then to
              when :from then from
              when :event then event
              else (attributes.delete(name) || event_args.shift)
              end
            }
            #{proc_body}
          end
        EOF
      end

      def around_callback?
        callback_type == :around
      end

      def name_arguments_string
        raise NotImplementedError, 'Abstract Method Called'
      end

      def kw_arguments_string
        params = kw_params.map do |name|
          "#{name}: attributes.delete(#{name.inspect})"
        end
        params.join(', ') if params.any?
      end

      def keyrest_string
        '**attributes' if keyrest_param
      end

      def rest_param_string
        '*event_args' if rest_param
      end

      def procedure_string
        raise NotImplementedError, 'Abstract Method Called'
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

      def parameters
        raise NotImplementedError, 'Abstract Method Called'
      end

      def arity
        raise NotImplementedError, 'Abstract Method Called'
      end
    end
  end
end
