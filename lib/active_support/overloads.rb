require 'active_support/callbacks'

module ActiveSupport
  module CallbackOverloads
    private
    def make_lambda(filter)
      if filter.kind_of? Workflow::Callbacks::TransitionCallback
        super(filter.wrapper)
      else
        super
      end
    end

    def compute_identifier(filter)
      if filter.kind_of? Workflow::Callbacks::TransitionCallback
        super(filter.raw_proc)
      else
        super
      end
    end
  end
end

class ::ActiveSupport::Callbacks::Callback
  prepend ActiveSupport::CallbackOverloads
end
