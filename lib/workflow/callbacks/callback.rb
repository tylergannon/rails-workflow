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
      def initialize(expression, inverted=false)
        @expression = expression
        @callback     = make_lambda(expression)
        if inverted
          @callback = invert_lambda(@callback)
        end
      end

      def call(target)
        callback.call(target, ->{})
      end

      def self.build_inverse(expression)
        new expression, true
      end

      private

      def invert_lambda(l)
        lambda { |*args, &blk| !l.call(*args, &blk) }
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
        case filter
        when Symbol
          lambda { |target, _, &blk| target.send filter, &blk }
        when String
          l = eval "lambda { |value| #{filter} }"
          lambda { |target, value| target.instance_exec(value, &l) }
        # when Conditionals::Value then filter
        when ::Proc
          if filter.arity > 1
            return lambda { |target, _, &block|
              raise ArgumentError unless block
              target.instance_exec(target, block, &filter)
            }
          end

          if filter.arity <= 0
            lambda { |target, _| target.instance_exec(&filter) }
          else
            lambda { |target, _| target.instance_exec(target, &filter) }
          end
        else
          scopes = Array(chain_config[:scope])
          method_to_call = scopes.map{ |s| public_send(s) }.join("_")

          lambda { |target, _, &blk|
            filter.public_send method_to_call, target, &blk
          }
        end
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
