
module Workflow
  module Callbacks
    module TransitionCallbacks
      class ProcWrapper < ::Workflow::Callbacks::TransitionCallback
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

        private

        def name_arguments_string
          params = name_params
          names  = []
          names << 'target'   if params.shift
          (names << 'callbacks') && params.shift if around_callback?
          names += params.map{|name| "name_proc.call(:#{name})"}
          return names.join(', ') if names.any?
        end

        def procedure_string
          '&raw_proc'
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
end
