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
        def self.extended(object)
          class << object
            alias_method :workflow_without_scopes, :workflow unless method_defined?(:workflow_without_scopes)
            alias_method :workflow, :workflow_with_scopes
          end
        end

        # Instructs Workflow which column to use to persist workflow state.
        #
        # @param [Symbol] column_name If provided, will set a new workflow column name.
        # @return [Symbol] The current (or new) name for the workflow column on this class.
        def workflow_column(column_name = nil)
          @workflow_state_column_name = column_name.to_sym if column_name
          if !instance_variable_defined?('@workflow_state_column_name') && superclass.respond_to?(:workflow_column)
            @workflow_state_column_name = superclass.workflow_column
          end
          @workflow_state_column_name ||= :workflow_state
        end

        def workflow_with_scopes(&specification)
          workflow_without_scopes(&specification)
          states = workflow_spec.states

          states.map(&:name).each do |state|
            define_singleton_method("with_#{state}_state") do
              where(workflow_column.to_sym => state.to_s)
            end

            define_singleton_method("without_#{state}_state") do
              where.not(workflow_column.to_sym => state.to_s)
            end
          end
        end
      end
    end
  end
end
