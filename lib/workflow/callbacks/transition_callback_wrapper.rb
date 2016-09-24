
module Workflow
  module Callbacks
    class TransitionCallbackWrapper
      attr_reader :callback_type, :raw_proc
      def initialize(callback_type, raw_proc, calling_class)
        @callback_type = callback_type
        @raw_proc      = raw_proc
        @calling_class = calling_class
      end

      def self.build_wrapper(callback_type, raw_proc, calling_class)
        if raw_proc.kind_of? ::Proc
          new(callback_type, raw_proc, calling_class).wrapper
        elsif raw_proc.kind_of? ::Symbol
          TransitionCallbackMethodWrapper.new(callback_type, raw_proc, calling_class)
        else
          raw_proc
        end
      end

      def wrapper
        arguments = [
          name_arguments_string,
          rest_param_string,
          kw_arguments_string,
          keyrest_string,
          procedure_string].compact.join(', ')

        raw_proc = self.raw_proc
        str = build_proc("target.instance_exec(#{arguments})")
        eval(str)
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
        params = name_params
        names  = []
        names << 'target'   if params.shift
        (names << 'callbacks') && params.shift if around_callback?
        names += params.map{|name| "name_proc.call(:#{name})"}
        return names.join(', ') if names.any?
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
        '&raw_proc'
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
        parameters.select do |type, name|
          types.include? type
        end.map(&:last)
      end

      def parameters
        raw_proc.parameters
      end

      def arity
        raw_proc.arity
      end
    end
  end
end
