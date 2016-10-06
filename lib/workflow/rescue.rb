# frozen_string_literal: true
module Workflow
  module Rescue
    extend ActiveSupport::Concern

    def transition!(name, *args, **attributes)
      super
    rescue StandardError => exception
      workflow_spec.rescue_with_handler(exception, object: self) || raise
    ensure
      workflow_spec.always_handlers.each do |callback|
        callback.call(self)
      end
    end
  end
end
