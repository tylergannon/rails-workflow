# frozen_string_literal: true
require 'rubygems'
require 'active_support/concern'
require 'active_support/callbacks'
require 'workflow/version'
require 'workflow/configuration'
require 'workflow/specification'
require 'workflow/callbacks'
require 'workflow/helper_method_configurator'
require 'workflow/adapters/active_record'
require 'workflow/adapters/remodel'
require 'workflow/adapters/active_record_validations'
require 'workflow/transition_context'
require 'active_support/overloads'

# See also README.markdown for documentation
module Workflow
  # @!parse include Callbacks
  # @!parse extend Callbacks::ClassMethods

  extend ActiveSupport::Concern
  include Callbacks
  include Errors

  # The application-wide Workflow configuration object
  CONFIGURATION = Configuration.new

  # Helper method for setting configuration options on {Workflow.config}
  #
  # @yield [Workflow::Configuration] config {Configuration} object to be manipulated.
  # @return [nil]
  def self.config(&block)
    block.call(CONFIGURATION) if block_given?
    CONFIGURATION
  end

  included do
    # Look for a hook; otherwise detect based on ancestor class.
    if respond_to?(:workflow_adapter)
      include workflow_adapter
    else
      if Object.const_defined?(:ActiveRecord) && self < ActiveRecord::Base
        include Adapter::ActiveRecord
        include Adapter::ActiveRecordValidations
      end
      if Object.const_defined?(:Remodel) && klass < Adapter::Remodel::Entity
        include Adapter::Remodel::InstanceMethods
      end
    end
  end

  # Returns a state object representing the current workflow state.
  #
  # @return [State] Current workflow state
  def current_state
    loaded_state = load_workflow_state
    res = workflow_spec.states.find { |t| t.name == loaded_state.to_sym } if loaded_state
    res || workflow_spec.initial_state
  end

  # Deprecated.  Check for false return value from {#transition!}
  # @return [Boolean] true if the last transition was halted by one of the transition callbacks.
  def halted?
    @halted
  end

  # Returns the reason given to a call to {#halt} or {#halt!}, if any.
  # @return [String] The reason the transition was aborted.
  attr_reader :halted_because

  # @api private
  # @return [Workflow::TransitionContext] During transition, or nil if no transition is underway.
  # During a state transition, contains transition-specific information:
  # * The name of the {Workflow::State} being exited,
  # * The name of the {Workflow::State} being entered,
  # * The name of the {Workflow::Event} that was fired,
  # * And whatever arguments were passed to the {Workflow#transition!} method.
  attr_reader :transition_context

  # Initiates state transition via the named event
  #
  # @param [Symbol] name name of event to initiate
  # @param [Array] args State transition arguments.
  # @return [Symbol] The name of the new state, or `false` if the transition failed.
  # TODO: connect args to documentation on how arguments are accessed during state transitions.
  def transition!(name, *args, **attributes)
    name = name.to_sym
    event = current_state.find_event(name)
    raise NoTransitionAllowed, "There is no event #{name} defined for the #{current_state.name} state" \
      if event.nil?

    @halted_because = nil
    @halted = false

    target = event.evaluate(self)

    return_value = false
    begin
      @transition_context = TransitionContext.new \
        from: current_state.name,
        to: target.name,
        event: name,
        event_args: args,
        attributes: attributes,
        named_arguments: workflow_spec.named_arguments

      run_all_callbacks do
        callback_value  = run_action_callback name, *args
        persist_value   = persist_workflow_state(target.name)
        return_value    = callback_value || persist_value
      end
    ensure
      @transition_context = nil
    end
    return_value
  end

  # Stop the current transition and set the reason for the abort.
  #
  # @param [String] reason Optional reason for halting transition.
  # @return [nil]
  def halt(reason = nil)
    @halted_because = reason
    @halted = true
    throw :abort
  end

  # Sets halt reason and raises [TransitionHaltedError] error.
  #
  # @param [String] reason Optional reason for halting
  # @return [nil]
  def halt!(reason = nil)
    @halted_because = reason
    @halted = true
    raise TransitionHaltedError, reason
  end

  #   The specification for this object.
  #   Could be set on a singleton for the object, on the object's class,
  #   Or else on a superclass of the object.
  # @return [Specification] The Specification that applies to this object.
  def workflow_spec
    # check the singleton class first
    class << self
      return workflow_spec if workflow_spec
    end

    c = self.class
    # using a simple loop instead of class_inheritable_accessor to avoid
    # dependency on Rails' ActiveSupport
    c = c.superclass until c.workflow_spec || !(c.include? Workflow)
    c.workflow_spec
  end

  private

  def has_callback?(action)
    # 1. public callback method or
    # 2. protected method somewhere in the class hierarchy or
    # 3. private in the immediate class (parent classes ignored)
    action = action.to_sym
    respond_to?(action) ||
      self.class.protected_method_defined?(action) ||
      private_methods(false).map(&:to_sym).include?(action)
  end

  def run_action_callback(action_name, *args)
    action = action_name.to_sym
    if has_callback?(action)
      meth = method(action)
      check_method_arity! meth, *args
      meth.call *args
    end
  end

  def check_method_arity!(method, *args)
    arity = method.arity

    unless (arity >= 0 && args.length == arity) || (arity.negative? && (args.length + 1) >= arity.abs)
      raise CallbackArityError, "Method #{method.name} has arity #{arity} but was called with #{args.length} arguments."
    end
  end

  # load_workflow_state and persist_workflow_state
  # can be overriden to handle the persistence of the workflow state.
  #
  # Default (non ActiveRecord) implementation stores the current state
  # in a variable.
  #
  # Default ActiveRecord implementation uses a 'workflow_state' database column.
  def load_workflow_state
    @workflow_state if instance_variable_defined? :@workflow_state
  end

  def persist_workflow_state(new_value)
    @workflow_state = new_value
  end

  module ClassMethods
    attr_reader :workflow_spec

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

    ##
    # Define workflow for the class.
    #
    # @yield [] Specification of workflow. Example below and in README.markdown
    # @return [nil]
    #
    # Workflow definition takes place inside the yielded block.
    # @see Specification::state
    # @see Specification::event
    #
    # ~~~ruby
    #
    # class Article
    #   include Workflow
    #   workflow do
    #     state :new do
    #       event :submit, :transitions_to => :awaiting_review
    #     end
    #     state :awaiting_review do
    #       event :review, :transitions_to => :being_reviewed
    #     end
    #     state :being_reviewed do
    #       event :accept, :transitions_to => :accepted
    #       event :reject, :transitions_to => :rejected
    #     end
    #     state :accepted
    #     state :rejected
    #   end
    # end
    #
    # ~~~
    #
    def workflow(&specification)
      @workflow_spec = Specification.new({}, &specification)
      HelperMethodConfigurator.new(@workflow_spec, self).configure!
    end
  end
end
