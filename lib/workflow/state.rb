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
    # @!attribute [r] tags
    #   @return [Array] Tags for this state.
    attr_reader :name, :events, :tags

    # @api private
    # For creating {Workflow::State} objects please see {Specification#state}
    # @param [Symbol] name Name of the state being created. Must be unique within its workflow.
    # @param [Array] all_states All states defined for this workflow, used for sorting.
    # @param [Hash] meta Optional metadata for this state.
    def initialize(name, all_states, tags: [], **meta)
      @name = name.to_sym
      @all_states = all_states
      @events = []
      @tags = [tags].flatten.uniq
      unless @tags.reject { |t| t.is_a? Symbol }
        raise WorkflowDefinitionError, "Tags can only include symbols, state: [#{name}]"
      end

      meta.each do |meta_name, value|
        class_eval do
          attr_accessor meta_name
        end
        instance_variable_set("@#{meta_name}", value)
      end
    end

    # Returns the event with the given name.
    # @param [Symbol] name name of event to find
    # @return [Workflow::Event] The event with the given name, or `nil`
    def find_event(name)
      events.find { |t| t.name == name }
    end

    # Define an event on this specification.
    # Must be called within the scope of the block within a call to {Workflow::Specification#state}.
    #
    # @param [Symbol] name The name of the event
    # @param [Symbol] to Optional name of {Workflow::State} this event will transition to.
    #                     Must be omitted if a block is provided.
    # @param [Hash] meta Optional hash of metadata to be stored on the event object.
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
    def on(name, to: nil, tags: [], **meta, &transitions)
      check_can_add_transition!(name, to: to, &transitions)
      event = Workflow::Event.new(name, tags: tags, **meta)

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

    class << self
      def beyond?(other)
        -> { current_state > other }
      end
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

    def to_s
      name.to_s
    end

    # Overloaded comparison operator.  Workflow states are sorted according to the order
    # in which they were defined.
    #
    # @param [Workflow::State] other state or Symbol name to be compared against.
    # @return [Integer]
    def <=>(other)
      if other.is_a?(Symbol)
        state = all_states.find { |s| s.name == other }
        raise Errors::StateComparisonError.new(self, other) unless state
        other = state
      end
      all_states.index(self) <=> all_states.index(other)
    end

    private

    # @api private
    # @!attribute [r] all_states
    #   @return [Array] All states defined on my workflow.  Used for sorting.
    attr_reader :all_states
  end
end
