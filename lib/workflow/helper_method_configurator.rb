# frozen_string_literal: true
module Workflow
  class HelperMethodConfigurator
    attr_reader :workflow_spec, :workflow_class

    def initialize(workflow_spec, workflow_class)
      @workflow_spec  = workflow_spec
      @workflow_class = workflow_class
    end

    def configure!
      undefine_methods_defined_by_workflow_spec if has_inherited_workflow_spec?
      create_instance_methods
    end

    def create_instance_methods
      workflow_spec.states.each do |state|
        state_name = state.name
        workflow_class.module_eval do
          define_method "#{state_name}?" do
            state_name == current_state.name
          end
        end

        state.events.each do |event|
          define_method_for_event(event) unless event_method?(event)
        end
      end
    end

    private

    def event_method?(event)
      workflow_class.instance_methods.include?(event_method_name(event))
    end

    def event_method_name(event)
      "#{event.name}!".to_sym
    end

    def define_method_for_event(event)
      workflow_class.module_eval do
        define_method "#{event.name}!".to_sym do |*args|
          transition!(event.name, *args)
        end

        define_method "can_#{event.name}?" do
          return !!current_state.find_event(event.name)&.evaluate(self)
        end
      end
    end

    def has_inherited_workflow_spec?
      workflow_class.superclass.respond_to?(:workflow_spec, true) &&
        workflow_class.superclass.workflow_spec
    end

    def undefine_methods_defined_by_workflow_spec
      workflow_class.superclass.workflow_spec.states.each do |state|
        state_name = state.name
        workflow_class.module_eval do
          undef_method "#{state_name}?"
        end

        state.events.each do |event|
          event_name = event.name
          workflow_class.module_eval do
            undef_method "#{event_name}!".to_sym
            undef_method "can_#{event_name}?"
          end
        end
      end
    end
  end
end
