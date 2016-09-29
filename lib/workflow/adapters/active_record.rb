# frozen_string_literal: true
module Workflow
  module Adapters
    module ActiveRecord
      extend ActiveSupport::Concern

      included do
        before_validation :write_initial_state
      end

      def load_workflow_state
        read_attribute(self.class.workflow_column)&.to_sym
      end

      # On transition the new workflow state is immediately saved in the
      # database, if configured to do so.
      def persist_workflow_state(new_value)
        # Rails 3.1 or newer
        if persisted? && Workflow.config.persist_workflow_state_immediately
          attrs = { self.class.workflow_column => new_value }
          if Workflow.config.touch_on_update_column
            attrs[:updated_at] = DateTime.now
          end
          update_columns attrs
          new_value
        else
          self[self.class.workflow_column] = new_value
        end
      end

      # Motivation: even if NULL is stored in the workflow_state database column,
      # the current_state is correctly recognized in the Ruby code. The problem
      # arises when you want to SELECT records filtering by the value of initial
      # state. That's why it is important to save the string with the name of the
      # initial state in all the new records.
      private def write_initial_state
        write_attribute self.class.workflow_column, current_state.name
      end

      # This module will automatically generate ActiveRecord scopes based on workflow states.
      # The name of each generated scope will be something like `with_<state_name>_state`
      #
      # Examples:
      #
      # Article.with_pending_state # => ActiveRecord::Relation
      # Payment.without_refunded_state # => ActiveRecord::Relation
      # `
      # Example above just adds `where(:state_column_name => 'pending')` or
      # `where.not(:state_column_name => 'pending')` to AR query and returns
      # ActiveRecord::Relation.
      module ClassMethods
        # Instructs Workflow which column to use to persist workflow state.
        #
        # @param [Symbol] column_name If provided, will set a new workflow column name.
        # @return [Symbol] The current (or new) name for the workflow column on this class.
        def workflow_column(column_name = nil)
          @workflow_column = column_name.to_sym if column_name
          @workflow_column ||= superclass_workflow || :workflow_state
        end

        def workflow(&specification)
          super
          workflow_spec.states.each { |state| define_scopes(state) }
        end

        # Find objects that are in a terminal state - no available
        # event transitions
        # @return [ActiveRecord::Relation] ActiveRecord query object meeting the criteria
        def in_terminal_state
          with_state workflow_spec.states.select(&:terminal?)
        end

        # Find objects that are not in a terminal state
        # @return [ActiveRecord::Relation] ActiveRecord query object meeting the criteria
        def not_in_terminal_state
          with_state(workflow_spec.states.reject(&:terminal?))
        end

        # Locate objects that are in a state tagged with the given tag(s)
        #
        # @param [Symbol] tags List of tags that apply
        # @return [ActiveRecord::Relation] ActiveRecord query object meeting the criteria
        def state_tagged_with(*tags)
          with_state workflow_spec.states.tagged_with(tags)
        end

        # Locate objects that are not in a state tagged with the given tag(s)
        #
        # @param [Symbol] tags List of tags the objects (and their states) should not have
        # @return [ActiveRecord::Relation] ActiveRecord query object meeting the criteria
        def state_not_tagged_with(*tags)
          with_state workflow_spec.states.not_tagged_with(tags)
        end

        # Find objects in the given state(s)
        #
        # @param [Object] states Symbol, String or {Workflow::State} objects
        # @return [ActiveRecord::Relation] ActiveRecord query object meeting the criteria
        def with_state(*states)
          states = [states].flatten
          states.map! do |state|
            if state.is_a?(Workflow::State)
              state.name.to_s
            else
              state.to_s
            end
          end
          where(workflow_state: states)
        end

        private

        def superclass_workflow
          superclass.workflow_column if superclass.respond_to?(:workflow_column)
        end

        def define_scopes(state)
          state_name = state.name

          scope "with_#{state_name}_state", lambda {
            where(workflow_column => state_name)
          }

          scope "without_#{state_name}_state", lambda {
            where.not(workflow_column => state_name)
          }
        end
      end
    end
  end
end
