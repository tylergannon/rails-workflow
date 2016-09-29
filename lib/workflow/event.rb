# frozen_string_literal: true
module Workflow
  class Event
    # @!attribute [r] name
    #   @return [Symbol] The name of the event.
    # @!attribute [r] transitions
    #   @return [Array] Array of {Workflow::Event::Transition}s defined for this event.
    # @!attribute [r] meta
    #   @return [Hash] Extra information defined for this event.
    # @!attribute [r] tags
    #   @return [Array] Tags for this event.
    attr_reader :name, :transitions, :meta, :tags

    # @api private
    # See {Workflow::State#on} for creating objects of this class.
    # @param [Symbol] name The name of the event to create.
    # @param [Hash] meta Optional Metadata for this object.
    # @param [Array] tags Tags for this event.
    def initialize(name, tags: [], **meta)
      @name = name.to_sym
      @transitions = []
      @meta = meta || {}
      @tags = [tags].flatten.uniq
      unless @tags.reject { |t| t.is_a? Symbol }
        raise WorkflowDefinitionError, "Tags can only include symbols, event: [#{name}]"
      end

      meta.each do |meta_name, value|
        class_eval do
          attr_accessor meta_name
        end
        instance_variable_set("@#{meta_name}", value)
      end
    end

    # @return [String] Titleized name of this event.
    def title
      name.to_s.titleize
    end

    def valid?
      transitions.any?
    end

    def inspect
      "<Event name=#{name.inspect} transitions(#{transitions.length})=#{transitions.inspect}>"
    end

    # Returns the {Workflow::State} that the target object should enter.
    # This will be the first one in the list of transitions, whose conditions apply
    # to the target object in its present state.
    # @param [Object] target An object of the class that this event was defined on.
    # @return [Workflow::State] The first applicable destination state, or nil if none.
    def evaluate(target)
      transitions.find do |transition|
        transition.matches? target
      end&.target_state
    end

    def evaluate!(target)
      state_name = evaluate(target)
      unless state_name
        raise NoMatchingTransitionError, "No matching transition found on #{name}
          for target #{target}.  Consider adding a catchall transition.".squish
      end
      state_name
    end

    # Add a {Workflow::Transition} to the possible {#transitions} for this event.
    #
    # @param [Symbol] target_state the name of the state target state if this transition matches.
    # @option conditions_def [Symbol] :if Name of instance method to evaluate. e.g. `:valid?`
    # @option conditions_def [Array] :if Mixed array of Symbol, String or Proc conditions.
    #                                       All must match for the transition to apply.
    # @option conditions_def [String] :if A string to evaluate on the target.
    #                                       e.g. `"self.foo == :bar"`
    # @option conditions_def [Proc] :if A proc which will be evaluated on the object
    #                                       e.g. `->{self.foo == :bar}`
    # @option conditions_def [Symbol] :unless Same Like `:if` but all conditions must **not** match
    # @yield [] Optional block which, if provided, becomes an `:if` condition for the transition.
    # @return [nil]
    def to(target_state, **conditions_def, &block)
      transitions << Transition.new(target_state, conditions_def, &block)
    end

    # @api private
    # Represents a possible transition via the event on which it is defined.
    class Transition
      # @!attribute [r] target_state
      #   @return [Workflow::State] The target state for this transition.
      attr_accessor :target_state

      # Whether or not the conditions match for the target object.
      #
      # @param [Object] target an object of the class for which this event/transition was defined.
      # @return [Boolean] True if all conditions apply.
      def matches?(target)
        conditions.apply?(target)
      end

      # @param [Symbol] target_state the name of the state target state if this transition matches.
      # @param [Hash] conditions_def See {Event#to}
      def initialize(target_state, conditions_def, &block)
        @target_state = target_state
        @conditions = Conditions.new conditions_def, &block
      end

      def inspect
        "<to=#{target_state.inspect} conditions=#{conditions.inspect}"
      end

      private

      # @!attribute [r] conditions
      #   @return [Workflow::Event::Conditions] Conditions for this transition.
      attr_reader :conditions
    end

    # @api private
    # Maintains a list of callback procs which are evaluted to determine if the
    # transition on which they were defined is valid for an object in its current state.
    # Borrowed from ActiveSupport::Callbacks
    # See [original source here](https://github.com/rails/rails/blob/bca2e69b785fa3cdbe148b0d2dd5d3b58f6daf53/activesupport/lib/active_support/callbacks.rb#L419)
    class Conditions
      def initialize(**options, &block)
        @if      = Array(options[:if])
        @unless  = Array(options[:unless])
        @if << block if block_given?
        @conditions_lambdas = conditions_lambdas
      end

      def inspect
        "if: #{@if}, unless: #{@unless}"
      end

      def apply?(target)
        @conditions_lambdas.all? { |l| l.call(target) }
      end

      private

      def conditions_lambdas
        @if.map { |c| Callbacks::Callback.build c } +
          @unless.map { |c| Callbacks::Callback.inverted c }
      end
    end
  end
end
