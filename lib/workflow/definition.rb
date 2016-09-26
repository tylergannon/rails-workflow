module Workflow
  module Definition
    extend ActiveSupport::Concern


      # Returns a state object representing the current workflow state.
      #
      # @return [State] Current workflow state
      def current_state
        loaded_state = load_workflow_state
        res = workflow_spec.states.find { |t| t.name == loaded_state.to_sym } if loaded_state
        res || workflow_spec.initial_state
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


      module ClassMethods
        attr_reader :workflow_spec

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
end
