# frozen_string_literal: true
require 'workflow/state'
require 'workflow/event'
require 'workflow/errors'

module Workflow
  # Metadata object describing available states and state transitions.
  class Specification
    include ActiveSupport::Callbacks
    include ActiveSupport::Rescuable::ClassMethods

    # The state objects defined for this specification
    # @return [Array]
    attr_reader :states

    # The event objects defined for this specification
    # @return [Array]
    attr_reader :events

    # State object to be given to newly created objects under this workflow.
    # @return [State]
    attr_reader :initial_state

    # Optional metadata stored with this workflow specification
    # @return [Hash]
    attr_reader :meta

    # List of symbols, for attribute accessors to be added to {TransitionContext} object
    # @return [Array]
    attr_reader :named_arguments

    attr_accessor :rescue_handlers

    attr_accessor :always_handlers

    define_callbacks :spec_definition

    set_callback(:spec_definition, :after) do |spec|
      spec.states.each do |state|
        state.events.each do |event|
          event.transitions.each do |transition|
            target_state = spec.find_state(transition.target_state)
            if target_state.nil?
              raise Errors::NoSuchStateError.new(event, transition)
            end
            transition.target_state = target_state
          end
        end
      end
    end

    set_callback(:spec_definition, :after, :collect_events)

    # Find the state with the given name.
    #
    # @param [Symbol] name Name of state to find.
    # @return [Workflow::State] The state with the given name.
    def find_state(name)
      states.find { |t| t.name == name.to_sym }
    end

    # @return [Array] Array of unique event names defined for this workflow spec.
    def event_names
      events.map(&:name).uniq
    end

    # @return [Array] Names of states defined on this workflow spec.
    def state_names
      states.map(&:name)
    end

    def always(*names, &block)
      names.each do |name|
        always_handlers << Workflow::Callbacks::Callback.build(name)
      end
      always_handlers << Workflow::Callbacks::Callback.build(block) if block_given?
    end

    # @api private
    #
    # @param [Hash] meta Metadata
    # @yield [] Block for workflow definition
    # @return [Specification]
    def initialize(meta = {}, &specification)
      @states = []
      @meta = meta
      @rescue_handlers = []
      @always_handlers = []
      run_callbacks :spec_definition do
        instance_eval(&specification)
      end
    end

    # Define a new state named [name]
    #
    # @param [Symbol] name name of state
    # @param [Hash] meta Metadata to be stored with the state within the {Specification} object
    # @param [Array] tags Tags to apply to the {Workflow::State} object
    # @yield [] block defining events for this state.
    # @return [nil]
    def state(name, tags: [], **meta, &events)
      name = name.to_sym
      new_state = Workflow::State.new(name, @states, tags: tags, **meta)
      @initial_state ||= new_state
      @states << new_state
      new_state.instance_eval(&events) if block_given?
    end

    # Specify attributes to make available on the {TransitionContext} object
    # during transitions taking place in this specification.
    # The attributes' values will be taken in order from the arguments passed to
    # the event transit method call.
    #
    # @param [Array] names A list of symbols
    # @return [nil]
    def event_args(*names)
      @named_arguments = names
    end

    # Also create additional event transitions that will move each configured transition
    # in the reverse direction.
    #
    # @return [nil]
    #
    # ```ruby
    # class Article
    #   include Workflow
    #   workflow do
    #     define_revert_events!
    #     state :foo do
    #       on :bar, to: :bax
    #     end
    #     state :bax
    #   end
    # end
    #
    # a = Article.new
    # a.transition! :foo
    # a.current_state.name          # => :bax
    # a.transition! :revert_bar
    # a.current_state.name          # => :foo
    # ```
    def define_revert_events!
      @define_revert_events = true
    end

    def unique_event_names
      states.collect(&:events).flatten.collect(&:name).flatten.uniq
    end

    def define_revert_events?
      @define_revert_events
    end

    private

    def collect_events
      @events = states.map(&:events).flatten
    end
  end
end
