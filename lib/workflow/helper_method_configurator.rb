# frozen_string_literal: true
module Workflow
  class HelperMethodConfigurator
    attr_reader :workflow_spec, :workflow_class

    def initialize(workflow_spec, workflow_class)
      @workflow_spec  = workflow_spec
      @workflow_class = workflow_class
    end

    def configure!
      undefine_methods_defined_by_workflow_spec if inherited_workflow_spec?
      define_revert_events if workflow_spec.define_revert_events?
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

    def define_revert_events
      workflow_spec.states.each do |state|
        reversible_events(state).each do |event|
          revert_event_name = "revert_#{event.name}".to_sym
          from_state_for_revert = event.transitions.first.target_state
          from_state_for_revert.on revert_event_name, to: state
        end
      end
    end

    def reversible_events(state)
      state.events.select do |e|
        e.name !~ /^revert_/ && e.transitions.length == 1
      end
    end

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
          current_state.find_event(event.name)&.evaluate(self)
        end
      end
    end

    def inherited_workflow_spec?
      workflow_class.superclass.respond_to?(:workflow_spec, true) &&
        workflow_class.superclass.workflow_spec
    end

    def undefine_methods_defined_by_workflow_spec
      superclass_workflow_spec.states.each do |state|
        workflow_class.class_exec(state.name, &undef_state_method_proc)

        state.events.each do |event|
          workflow_class.class_exec(event.name, &undef_event_method_procs)
        end
      end
    end

    def superclass_workflow_spec
      workflow_class.superclass.workflow_spec
    end

    def undef_state_method_proc
      -> (state) { undef_method "#{state}?" }
    end

    def undef_event_method_procs
      lambda do |event_name|
        undef_method "#{event_name}!"
        undef_method "can_#{event_name}?"
      end
    end
  end
end
