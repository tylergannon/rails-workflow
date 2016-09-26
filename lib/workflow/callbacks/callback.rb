# frozen_string_literal: true
module Workflow
  module Callbacks
    #
    #  Receives an expression and generates a lambda that can be called against
    #  an object, for use in callback logic.
    #
    #  Adapted from ActiveSupport::Callbacks
    #  https://github.com/rails/rails/blob/bca2e69b785fa3cdbe148b0d2dd5d3b58f6daf53/activesupport/lib/active_support/callbacks.rb#L296
    class Callback
      include Comparable

      attr_reader :expression, :callback
      def initialize(expression, inverted = false)
        @expression = expression
        @callback = make_lambda(expression)
        @callback = invert_lambda(@callback) if inverted
      end

      def call(target)
        callback.call(target, -> {})
      end

      def self.inverted(expression)
        build(expression, true)
      end

      def self.build(expression, inverted = false)
        case expression
        when Symbol
          MethodCallback.new(expression, inverted)
        when String
          StringCallback.new(expression, inverted)
        when Proc
          ProcCallback.new(expression, inverted)
        end
      end

      private

      def invert_lambda(l)
        ->(*args, &blk) { !l.call(*args, &blk) }
      end

      # Filters support:
      #
      #   Symbols:: A method to call.
      #   Strings:: Some content to evaluate.
      #   Procs::   A proc to call with the object.
      #   Objects:: An object with a <tt>before_foo</tt> method on it to call.
      #
      # All of these objects are converted into a lambda and handled
      # the same after this point.
      def make_lambda(filter)
      end

      def compute_identifier(filter)
        case filter
        when String, ::Proc
          filter.object_id
        else
          filter
        end
      end
    end
  end
end

require 'workflow/callbacks/proc_callback'
require 'workflow/callbacks/string_callback'
require 'workflow/callbacks/method_callback'
