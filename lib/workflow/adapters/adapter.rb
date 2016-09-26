module Workflow
  module Adapters
    module Adapter
      extend ActiveSupport::Concern
      included do
        # Look for a hook; otherwise detect based on ancestor class.
        if respond_to?(:workflow_adapter)
          include workflow_adapter
        else
          if Adapters.const_defined?(:ActiveRecord) && self < ::ActiveRecord::Base
            include Adapters::ActiveRecord
            include ActiveRecordValidations
          end

          if Object.const_defined?(:Remodel) && klass < Adapter::Remodel::Entity
            include :Remodel
          end
        end
      end
    end
  end
end
