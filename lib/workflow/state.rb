# frozen_string_literal: true
module Workflow
  # Represents one state for the defined workflow,
  # with a list of {Workflow::Event}s that can transition to
  # other states.
  class State
    include Comparable

    # @!attribute [r] name
    #   @return [Symbol] The name of the state.
    # @!attribute [r] events
    #   @return [Array] Array of {Workflow::Event}s defined for this state.
    # @!attribute [r] meta
    #   @return [Hash] Extra information defined for this state.
    attr_reader :name, :events, :meta

    # @api private
    # For creating {Workflow::State} objects please see {Specification#state}
    # @param [Symbol] name Name of the state being created. Must be unique within its workflow.
    # @param [Fixnum] sequence Sort location among states on this workflow.
    # @param [Hash] meta: Optional metadata for this state.
    def initialize(name, sequence, meta: {})
      @name = name.to_sym
      @sequence = sequence
      @events = []
      @meta = meta
    end

    # Returns the event with the given name.
    # @param [Symbol] name name of event to find
    # @return [Workflow::Event] The event with the given name, or `nil`
    def find_event(name)
      events.find { |t| t.name == name }
    end

    # Define an event on this specification.
    # Must be called within the scope of the block within a call to {#state}.
    #
    # @param [Symbol] name The name of the event
    # @param [Symbol] to: Optional name of {Workflow::State} this event will transition to.
    #                     Must be omitted if a block is provided.
    # @param [Hash] meta: Optional hash of metadata to be stored on the event object.
    # @yield [] Transitions definition for this event.
    # @return [nil]
    #
    # ```ruby
    # workflow do
    #  state :new do
    #    on :review, to: :being_reviewed
    #
    #    on :submit do
    #      to :submitted,
    #        if:     [ "name == 'The Dude'", :abides?, -> (rug) {rug.tied_the_room_together?}],
    #        unless: :nihilist?
    #
    #      to :trash, unless: :body?
    #      to :another_place do |article|
    #        article.foo?
    #      end
    #   end
    # end
    #
    #  state :kitchen
    #  state :the_bar
    #  state :the_diner
    # end
    # ```
    def on(name, to: nil, meta: {}, &transitions)
      check_can_add_transition!(name, to: to, &transitions)
      event = Workflow::Event.new(name, meta: meta)

      if to
        event.to to
      else
        event.instance_eval(&transitions)
      end

      unless event.valid?
        raise Errors::NoTransitionsDefinedError.new(self, event)
      end

      events << event
      nil
    end

    private def check_can_add_transition!(name, to: nil)
      raise Errors::DualEventDefinitionError if to && block_given?

      unless to || block_given?
        raise Errors::WorkflowDefinitionError, "No event target given for event #{name}"
      end

      raise Errors::EventNameCollisionError.new(self, name) if find_event(name)
    end

    # @return [String] String representation of object
    def inspect
      "<State name=#{name.inspect} events(#{events.length})=#{events.inspect}>"
    end

    # Overloaded comparison operator.  Workflow states are sorted according to the order
    # in which they were defined.
    #
    # @param [Workflow::State] other state to be compared against.
    # @return [Integer]
    def <=>(other)
      raise Errors::StateComparisonError, other unless other.is_a?(State)
      sequence <=> other.send(:sequence)
    end

    private

    # @api private
    # @!attribute [r] sequence
    #   @return [Fixnum] The position of this state within the
    #                     order it was defined for in its workflow.
    attr_reader :sequence
  end
end
