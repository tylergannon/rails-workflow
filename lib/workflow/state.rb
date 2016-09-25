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
    # @param [Symbol] name The name of the state being created.  Should be unique within its workflow.
    # @param [Fixnum] sequence Sequencing number that will affect sorting comparisons with other states.
    # @param [Hash] meta: Optional metadata for this state.
    def initialize(name, sequence, meta: {})
      @name, @sequence, @events, @meta = name.to_sym, sequence, [], meta
    end

    # Returns the event with the given name.
    # @param [Symbol] name name of event to find
    # @return [Workflow::Event] The event with the given name, or `nil`
    def find_event(name)
      events.find{|t| t.name == name}
    end

    # Define an event on this specification.
    # Must be called within the scope of the block within a call to {#state}.
    #
    # @param [Symbol] name The name of the event
    # @param [Symbol] to: Optional name of {Workflow::State} this event will transition to.  Must be omitted if a block is provided.
    # @param [Hash] meta: Optional hash of metadata to be stored on the event object.
    # @yield [] Transitions definition for this event.
    # @return [nil]
    #
    #```ruby
    #workflow do
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
    #end
    #```
    def on(name, to: nil, meta: {}, &transitions)
      if to && block_given?
        raise Errors::WorkflowDefinitionError.new("Event target can only be received in the method call or the block, not both.")
      end

      unless to || block_given?
        raise Errors::WorkflowDefinitionError.new("No event target given for event #{name}")
      end

      if find_event(name)
        raise Errors::WorkflowDefinitionError.new("Already defined an event [#{name}] for state[#{self.name}]")
      end

      event = Workflow::Event.new(name, meta: meta)

      if to
        event.to to
      else
        event.instance_eval(&transitions)
      end

      if event.transitions.empty?
        raise Errors::WorkflowDefinitionError.new("No transitions defined for event [#{name}] on state [#{self.name}]")
      end

      events << event
      nil
    end

    # @return [String] String representation of object
    def inspect
      "<State name=#{name.inspect} events(#{events.length})=#{events.inspect}>"
    end

    # Overloaded comparison operator.  Workflow states are sorted according to the order
    # in which they were defined.
    #
    # @param [Workflow::State] other_state state to be compared against.
    # @return [Integer]
    def <=>(other_state)
      unless other_state.is_a?(State)
        raise StandardError.new "Other State #{other_state} is a #{other_state.class}.  I can only be compared with a Workflow::State."
      end
      self.sequence <=> other_state.send(:sequence)
    end

    private
    # @api private
    # @!attribute [r] sequence
    #   @return [Fixnum] The position of this state within the order it was defined for in its workflow.
    attr_reader :sequence

  end
end
