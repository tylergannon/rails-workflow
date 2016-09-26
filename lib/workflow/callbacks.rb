# frozen_string_literal: true
require 'workflow/callbacks/callback'
require 'workflow/callbacks/transition_callback'
require 'workflow/callbacks/transition_callbacks/method_wrapper'
require 'workflow/callbacks/transition_callbacks/proc_wrapper'

module Workflow
  module Callbacks
    extend ActiveSupport::Concern
    include ActiveSupport::Callbacks

    CALLBACK_MAP = {
      transition: :event,
      exit: :from,
      enter: :to
    }.freeze

    included do
      CALLBACK_MAP.keys.each do |type|
        define_callbacks type,
                         skip_after_callbacks_if_terminated: true
      end
    end

    module ClassMethods
      def ensure_after_transitions(name = nil, **opts, &block)
        ensure_procs = [name, block].compact.map do |exe|
          Callback.build(exe)
        end

        prepend_around_transition(**opts) do |obj, callbacks|
          begin
            callbacks.call
          ensure
            ensure_procs.each { |l| l.callback.call obj, -> {} }
          end
        end
      end

      EMPTY_LAMBDA = -> {}

      def on_error(error_class = Exception, **opts, &block)
        error_procs  = build_lambdas([opts.delete(:rescue), block])
        ensure_procs = build_lambdas(opts.delete(:ensure))

        prepend_around_transition(**opts, &on_error_proc(error_class, error_procs, ensure_procs))
      end

      private def on_error_proc(error_class, error_procs, ensure_procs)
        proc do |_obj, callbacks|
          begin
            callbacks.call
          rescue error_class => ex
            instance_exec(ex, &block) if block_given?
            error_procs.each { |l| l.callback.call self, EMPTY_LAMBDA }
          ensure
            ensure_procs.each { |l| l.callback.call self, EMPTY_LAMBDA }
          end
        end
      end

      private def build_lambdas(*names)
        [names].flatten.compact.map do |name|
          Callback.build name
        end
      end

      ##
      # @!method before_transition
      #
      # :call-seq:
      #   before_transition(*instance_method_names, options={})
      #   before_transition(options={}, &block)
      #
      # Append a callback before transition.
      # Instance methods used for `before` and `after` transitions
      # receive no parameters.  Instance methods for `around` transitions will be given a block,
      # which must be yielded/called in order for the sequence to continue.
      #
      # Using a block notation, the first parameter will be an instance of the object
      # under transition, while the second parameter (`around` transition only) will be
      # the block which should be called for the sequence to continue.
      #
      # == Transition Metadata
      #
      # Within the callback you can access the `transition_context` instance variable,
      # which will give you metadata and arguments passed to the transition.
      # See Workflow::TransitionContext
      #
      # == Options
      #
      # === If / Unless
      #
      # The callback will run `if` or `unless` the named method returns a truthy value.
      #
      #    #  Assuming some_instance_method returns a boolean,
      #    before_transition :do_something, if: :some_instance_method
      #    before_transition :do_something_else, unless: :some_instance_method
      #
      # === Only / Except
      #
      # The callback will run `if` or `unless` the event being processed is in the list given
      #
      #     #  Run this callback only on the `accept` and `publish` events.
      #     before_transition :do_something, only: [:accept, :publish]
      #     #  Run this callback on events other than the `accept` and `publish` events.
      #     before_transition :do_something_else, except: [:accept, :publish]
      #

      ##
      # @!method prepend_before_transition(*instance_method_names, options={})
      #
      # Something Interesting
      #
      # @overload prepend_before_transition(options={}, &block)
      #
      # Prepend a callback before transition, making it the first before transition called.
      # Options are the same as for the standard #before_transition method.

      ##
      # @!method skip_before_transition
      #
      # :call-seq: skip_before_transition(names)
      #
      # Skip a callback before transition.
      # Options are the same as for the standard #before_transition method.

      ##
      # @!method after_transition
      #
      # :call-seq:
      #   after_transition(*instance_method_names, options={})
      #   after_transition(options={}, &block)
      #
      # Append a callback after transition.
      # Instance methods used for `before` and `after` transitions
      # receive no parameters.  Instance methods for `around` transitions will be given a block,
      # which must be yielded/called in order for the sequence to continue.
      #
      # Using a block notation, the first parameter will be an instance of the object
      # under transition, while the second parameter (`around` transition only) will be
      # the block which should be called for the sequence to continue.
      #
      # == Transition Metadata
      #
      # Within the callback you can access the `transition_context` instance variable,
      # which will give you metadata and arguments passed to the transition.
      # See Workflow::TransitionContext
      #
      # == Options
      #
      # === If / Unless
      #
      # The callback will run `if` or `unless` the named method returns a truthy value.
      #
      #    #  Assuming some_instance_method returns a boolean,
      #    after_transition :do_something, if: :some_instance_method
      #    after_transition :do_something_else, unless: :some_instance_method
      #
      # === Only / Except
      #
      # The callback will run `if` or `unless` the event being processed is in the list given
      #
      #     #  Run this callback only on the `accept` and `publish` events.
      #     after_transition :do_something, only: [:accept, :publish]
      #     #  Run this callback on events other than the `accept` and `publish` events.
      #     after_transition :do_something_else, except: [:accept, :publish]
      #

      ##
      # @!method prepend_after_transition(*instance_method_names, options={})
      #
      # Something Interesting
      #
      # @overload prepend_after_transition(options={}, &block)
      #
      # Prepend a callback after transition, making it the first after transition called.
      # Options are the same as for the standard #after_transition method.

      ##
      # @!method skip_after_transition
      #
      # :call-seq: skip_after_transition(names)
      #
      # Skip a callback after transition.
      # Options are the same as for the standard #after_transition method.

      ##
      # @!method around_transition
      #
      # :call-seq:
      #   around_transition(*instance_method_names, options={})
      #   around_transition(options={}, &block)
      #
      # Append a callback around transition.
      # Instance methods used for `before` and `after` transitions
      # receive no parameters.  Instance methods for `around` transitions will be given a block,
      # which must be yielded/called in order for the sequence to continue.
      #
      # Using a block notation, the first parameter will be an instance of the object
      # under transition, while the second parameter (`around` transition only) will be
      # the block which should be called for the sequence to continue.
      #
      # == Transition Metadata
      #
      # Within the callback you can access the `transition_context` instance variable,
      # which will give you metadata and arguments passed to the transition.
      # See Workflow::TransitionContext
      #
      # == Options
      #
      # === If / Unless
      #
      # The callback will run `if` or `unless` the named method returns a truthy value.
      #
      #    #  Assuming some_instance_method returns a boolean,
      #    around_transition :do_something, if: :some_instance_method
      #    around_transition :do_something_else, unless: :some_instance_method
      #
      # === Only / Except
      #
      # The callback will run `if` or `unless` the event being processed is in the list given
      #
      #     #  Run this callback only on the `accept` and `publish` events.
      #     around_transition :do_something, only: [:accept, :publish]
      #     #  Run this callback on events other than the `accept` and `publish` events.
      #     around_transition :do_something_else, except: [:accept, :publish]
      #

      ##
      # @!method prepend_around_transition(*instance_method_names, options={})
      #
      # Something Interesting
      #
      # @overload prepend_around_transition(options={}, &block)
      #
      # Prepend a callback around transition, making it the first around transition called.
      # Options are the same as for the standard #around_transition method.

      ##
      # @!method skip_around_transition
      #
      # :call-seq: skip_around_transition(names)
      #
      # Skip a callback around transition.
      # Options are the same as for the standard #around_transition method.

      [:before, :after, :around].each do |callback|
        CALLBACK_MAP.each do |type, context_attribute|
          define_method "#{callback}_#{type}" do |*names, &blk|
            _insert_callbacks(names, context_attribute, blk) do |name, options|
              set_callback(type, callback, cb(callback, name, self), options)
            end
          end

          define_method "prepend_#{callback}_#{type}" do |*names, &blk|
            _insert_callbacks(names, context_attribute, blk) do |name, options|
              set_callback(type, callback, cb(callback, name, self), options.merge(prepend: true))
            end
          end

          # Skip a before, after or around callback. See _insert_callbacks
          # for details on the allowed parameters.
          define_method "skip_#{callback}_#{type}" do |*names|
            _insert_callbacks(names, context_attribute) do |name, options|
              skip_callback(type, callback, name, options)
            end
          end

          # *_action is the same as append_*_action
          alias_method :"append_#{callback}_#{type}", :"#{callback}_#{type}"
        end
      end

      private def cb(callback, name, target)
        Callbacks::TransitionCallback.build_wrapper(callback, name, target)
      end

      def applicable_callback?(_callback, procedure)
        arity = procedure.arity
        return true if arity.negative? || arity > 2

        [:key, :keyreq, :keyrest].include?(procedure.parameters[-1][0])
      end

      private

      def _insert_callbacks(callbacks, context_attribute, block = nil)
        options = callbacks.extract_options!
        _normalize_callback_options(options, context_attribute)
        callbacks.push(block) if block
        callbacks.each do |callback|
          yield callback, options
        end
      end

      def _normalize_callback_options(options, context_attribute)
        _normalize_callback_option(options, context_attribute, :only, :if)
        _normalize_callback_option(options, context_attribute, :except, :unless)
      end

      def _normalize_callback_option(options, context_attribute, from, to) # :nodoc:
        return unless options[from]

        all_names = Array(options[from]).map(&:to_sym).to_set
        from = proc do |record|
          all_names.include? record.transition_context.send(context_attribute).to_sym
        end
        options[to] = Array(options[to]).unshift(from)
      end
    end

    private

    #  TODO: Do something here.
    def halted_callback_hook(filter)
      # byebug
    end

    def run_all_callbacks(&block)
      catch(:abort) do
        run_callbacks :transition do
          throw(:abort) if false == run_callbacks(:exit) do
            throw(:abort) if false == run_callbacks(:enter, &block)
          end
        end
      end
    end
  end
end
