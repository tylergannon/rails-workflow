require 'active_support/callbacks'

module ActiveSupport
  # Overloads for {ActiveSupport::Callbacks::Callback} so it can recognize
  # {Workflow::Callbacks::TransitionCallback}, which is duck-type equivalent
  # to a lambda for the present purposes.
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

# Overload {ActiveSupport::Callbacks::Callback} with methods from {ActiveSupport::CallbackOverloads}.
# {Workflow::Callbacks::TransitionCallback}, which is duck-type equivalent
# to a lambda for the present purposes.
class ::ActiveSupport::Callbacks::Callback
  prepend ActiveSupport::CallbackOverloads
end
