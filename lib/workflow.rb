# frozen_string_literal: true
require 'rubygems'
require 'active_support/concern'
require 'active_support/callbacks'
require 'active_support/rescuable'
require 'workflow/version'
require 'workflow/configuration'
require 'workflow/specification'
require 'workflow/callbacks'
require 'workflow/rescue'
require 'workflow/helper_method_configurator'
require 'workflow/tag_method_configurator'
require 'workflow/adapters/active_record'
require 'workflow/adapters/remodel'
require 'workflow/transitions'
require 'workflow/definition'
require 'workflow/adapters/adapter'
require 'workflow/adapters/active_record_validations'
require 'workflow/transition_context'
require 'active_support/overloads'

# See also README.markdown for documentation
module Workflow
  # @!parse include Callbacks
  # @!parse include Transitions
  # @!parse include Definition
  # @!parse extend Callbacks::ClassMethods

  extend ActiveSupport::Concern
  include Callbacks
  include Errors
  include Transitions
  include Definition

  include Adapters::Adapter
  prepend Rescue

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
end
