# frozen_string_literal: true
module Workflow
  module Transitions
    extend ActiveSupport::Concern

    # @api private
    # @!attribute [r] transition_context
    # @return [Workflow::TransitionContext] During transition, or nil if no transition is underway.
    # During a state transition, contains transition-specific information:
    # * The name of the {Workflow::State} being exited,
    # * The name of the {Workflow::State} being entered,
    # * The name of the {Workflow::Event} that was fired,
    # * And whatever arguments were passed to the {Workflow#transition!} method.
    included do
      attr_reader :transition_context
    end

    # Initiates state transition via the named event
    #
    # @param [Symbol] name name of event to initiate
    # @param [Array] args State transition arguments.
    # @return [Symbol] The name of the new state, or `false` if the transition failed.
    # TODO: connect args to documentation on how arguments are accessed during state transitions.
    def transition!(name, *args, **attributes)
      @transition_context = prepare_transition(name, args, attributes)

      run_all_callbacks do
        persist_workflow_state(@transition_context.to)
      end
    ensure
      @transition_context = nil
    end

    # Stop the current transition and set the reason for the abort.
    #
    # @param [String] reason Optional reason for halting transition.
    # @return [nil]
    def halt(reason = nil)
      @halted_because = reason
      @halted = true
      throw :abort
    end

    # Sets halt reason and raises [TransitionHaltedError] error.
    #
    # @param [String] reason Optional reason for halting
    # @return [nil]
    def halt!(reason = nil)
      @halted_because = reason
      @halted = true
      raise Errors::TransitionHaltedError, reason
    end

    # Deprecated.  Check for false return value from {#transition!}
    # @return [Boolean] true if the last transition was halted by one of the transition callbacks.
    def halted?
      @halted
    end

    # Returns the reason given to a call to {#halt} or {#halt!}, if any.
    # @return [String] The reason the transition was aborted.
    attr_reader :halted_because

    # load_workflow_state and persist_workflow_state
    # can be overriden to handle the persistence of the workflow state.
    #
    # Default (non ActiveRecord) implementation stores the current state
    # in a variable.
    #
    # Default ActiveRecord implementation uses a 'workflow_state' database column.
    def load_workflow_state
      @workflow_state if instance_variable_defined? :@workflow_state
    end

    def persist_workflow_state(new_value)
      @workflow_state = new_value
    end

    def prepare_transition(name, args, attributes)
      event = current_state.find_event(name.to_sym)
      raise Errors::NoTransitionAllowed.new(current_state, name) unless event

      target = event.evaluate(self)

      TransitionContext.new \
        from: current_state.name,
        to: target.name,
        event: event.name,
        event_args: args,
        attributes: attributes,
        named_arguments: workflow_spec.named_arguments
    end
  end
end
