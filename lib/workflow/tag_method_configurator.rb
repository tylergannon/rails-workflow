# frozen_string_literal: true
module Workflow
  class TagMethodConfigurator
    attr_reader :workflow_spec, :workflow_class

    def initialize(workflow_spec, workflow_class)
      @workflow_spec  = workflow_spec
      @workflow_class = workflow_class
    end

    def configure!
      define_event_tag_methods
      define_tag_methods
      add_tagged_with_to_states_and_events
    end

    private

    def define_event_tag_methods
      tags = workflow_spec.events.map(&:tags).flatten
      tag_method_module = build_tag_method_module(tags, false)
      workflow_spec.events.each do |event|
        event.send :extend, tag_method_module
      end
    end

    def add_tagged_with_to_states_and_events
      workflow_spec.states.send :extend, TaggedWith
      workflow_spec.events.send :extend, TaggedWith
    end

    def build_tag_method_module(tags, include_state_helpers)
      tag_method_module = Module.new
      tag_method_module.send :include, StateTagHelpers if include_state_helpers
      tag_method_module.class_eval do
        tags.each do |tag|
          define_method "#{tag}?" do
            self.tags.include?(tag)
          end
        end
      end
      tag_method_module
    end

    module StateTagHelpers
      def initial?
        all_states.index(self).zero?
      end

      def terminal?
        events.empty?
      end
    end

    module TaggedWith
      def tagged_with(*tags)
        tags = [tags].flatten
        select { |item| (item.tags & tags).any? }
      end

      def not_tagged_with(*tags)
        tags = [tags].flatten
        reject { |item| (item.tags & tags).any? }
      end
    end

    def define_tag_methods
      tags = workflow_spec.states.map(&:tags).flatten.uniq
      tag_method_module = build_tag_method_module(tags, true)
      workflow_spec.states.each do |state|
        state.send :extend, tag_method_module
      end
    end
  end
end
