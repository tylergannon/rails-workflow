module Workflow
  class Event
    attr_reader :name, :transitions, :meta

    def initialize(name, meta)
      @name = name.to_sym
      @transitions = []
      @meta = meta || {}
    end

    def inspect
      "<Event name=#{name.inspect} transitions(#{transitions.length})=#{transitions.inspect}>"
    end

    def evaluate(target)
      transition = transitions.find{|t| t.apply? target}
      if transition
        return transition.target_state
      else
        nil
      end
    end

    def to(target_state, **conditions_def, &block)
      conditions = Conditions.new &&conditions_def, block
      self.transitions << Transition.new(target_state, conditions_def, &block)
    end

    private
    class Transition
      attr_accessor :target_state, :conditions
      def apply?(target)
        conditions.apply?(target)
      end
      # delegate :apply?, to: :conditions
      def initialize(target_state, conditions_def, &block)
        @target_state = target_state
        @conditions = Conditions.new conditions_def, &block
      end

      def inspect
        "<to=#{target_state.inspect} conditions=#{conditions.inspect}"
      end
    end

    class Conditions #:nodoc:#
      def initialize(**options, &block)
        @if      = Array(options[:if])
        @unless  = Array(options[:unless])
        @if      << block if block_given?
        @conditions_lambdas = conditions_lambdas
      end

      def inspect
        "if: #{@if}, unless: #{@unless}"
      end

      def apply?(target)
        @conditions_lambdas.all?{|l| l.call(target)}
      end

      private

      # From https://github.com/rails/rails/blob/bca2e69b785fa3cdbe148b0d2dd5d3b58f6daf53/activesupport/lib/active_support/callbacks.rb#L419
      def conditions_lambdas
        @if.map { |c| Callbacks::Callback.new c } +
          @unless.map { |c| Callbacks::Callback.new c, true }
      end
    end
  end
end
