# frozen_string_literal: true
require 'active_support/concern'
require 'English'

module Workflow
  module Adapters
    module ActiveRecordValidations
      extend ActiveSupport::Concern

      included do
        prepend RevalidateOnlyAfterAttributesChange
      end

      ###
      #
      # Captures instance method calls of the form `:transitioning_from_<state_name>`
      #   and `:transitioning_to_<state_name>`.
      #
      # For use with validators, e.g. `validates :foobar, presence: true,
      #   if: :transitioning_to_some_state?`
      #
      def method_missing(method, *args, &block)
        if method.to_s =~ /^transitioning_(from|to|via_event)_([\w_-]+)\?$/
          class_eval "
          def #{method}
            transitioning? direction: '#{$LAST_MATCH_INFO[1]}', state: '#{$LAST_MATCH_INFO[2]}'
          end
          "
          send method
        else
          super
        end
      end

      def respond_to_missing?(method_name, _include_private = false)
        method_name.to_s =~ /^transitioning_(from|to|via_event)_([\w_-]+)\?$/
      end

      def can_transition?(event_id)
        event = current_state.find_event(event_id)
        return false unless event

        from = current_state.name
        to = event.evaluate(self)

        return false unless to

        within_transition(from, to.name, event_id) do
          return valid?
        end
      ensure
        errors.clear
      end

      ###
      #
      # Executes the given block within a context that is able to give
      # correct answers to the questions, `:transitioning_from_<old_state>?`.
      # `:transitioning_to_<new_state>`, `:transitioning_via_event_<event_name>?`
      #
      # For use with validators, e.g. `validates :foobar, presence: true,
      # if: :transitioning_to_some_state?`
      #
      # = Example:
      #
      #    before_transition do |from, to, name, *args|
      #      @halted = !within_transition from, to, name do
      #        valid?
      #      end
      #    end
      #
      def within_transition(from, to, event)
        @transition_context = TransitionContext.new \
          from: from,
          to: to,
          event: event,
          attributes: {},
          event_args: []

        return yield
      ensure
        @transition_context = nil
      end

      # Override for ActiveRecord::Validations#valid?
      # Since we are validating inside of a transition,
      # We need to be able to maintain the errors list for the object
      # through future valid? calls or the list will be cleared
      # next time valid? is called.
      #
      # Once any attributes have changed on the object, the following call to {#valid?}
      # will cause revalidation.
      #
      # Note that a change on an association will not trigger a reset,
      # meaning that one should call `errors.clear` before {#valid?} will
      # trigger validations to run anew.
      module RevalidateOnlyAfterAttributesChange
        def valid?(context = nil)
          if errors.any? && !@changed_since_validation
            false
          else
            begin
              return super
            ensure
              @changed_since_validation = false
            end
          end
        end

        def write_attribute(attr_name, value)
          @changed_since_validation = true
          super
        end
      end

      module ClassMethods
        def halt_transition_unless_valid!
          before_transition unless: :valid? do |_model|
            throw :abort
          end
        end

        def wrap_transition_in_transaction!
          around_transition do |model, transition|
            model.with_lock do
              transition.call
            end
          end
        end
      end

      private

      def transitioning?(direction:, state:)
        state = state.to_sym
        return false unless transition_context
        case direction
        when 'from' then transition_context.from == state
        when 'to' then transition_context.to == state
        else transition_context.event == state
        end
      end
    end
  end
end
