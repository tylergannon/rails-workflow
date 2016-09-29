# frozen_string_literal: true
module Workflow
  module Errors
    class TransitionHaltedError < StandardError
      attr_reader :halted_because

      def initialize(msg = nil)
        @halted_because = msg
        super msg
      end
    end

    class NoMatchingTransitionError < StandardError
    end

    class WorkflowDefinitionError < StandardError
    end

    class NoTransitionsDefinedError < WorkflowDefinitionError
      def initialize(state, event)
        super("No transitions defined for event [#{event.name}] on state [#{state.name}]")
      end
    end

    class DualEventDefinitionError < WorkflowDefinitionError
      def initialize
        super('Event target can only be received in the method call or the block, not both.')
      end
    end

    class EventNameCollisionError < WorkflowDefinitionError
      def initialize(state, event_name)
        super("Already defined an event [#{event_name}] for state[#{state.name}]")
      end
    end

    class StateComparisonError < StandardError
      def initialize(state, other)
        super("Can't compare #{state} with #{other} bc [#{other}] is not a defined state.")
      end
    end

    class NoSuchStateError < WorkflowDefinitionError
      def initialize(event, transition)
        super("Event #{event.name} transitions to
              #{transition.target_state} but there is no such state.".squish)
      end
    end

    class NoTransitionAllowed < StandardError
      def initialize(state, event_name)
        super("There is no event #{event_name} defined for the #{state.name} state")
      end
    end

    class WorkflowError < StandardError
    end
  end
end
