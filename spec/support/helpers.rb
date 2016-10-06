class BasicWorkflowClass
  attr_accessor :messages
  include Workflow
  def initialize
    self.messages = []
  end
end

RSpec.shared_context 'Shared Helpers', shared_context: :metadata do
  def new_workflow_class(superklass = BasicWorkflowClass, &block)
    k = Class.new(superklass) do
      include Workflow unless included_modules.include?(Workflow)
    end
    if block_given?
      k.class_eval { workflow(&block) }
    end
    k
  end

  #
  # before do
  #   ActiveRecord::Base.establish_connection(
  #     :adapter => "sqlite3",
  #     :database  => ":memory:" #"tmp/test"
  #   )
  #
  #   # eliminate ActiveRecord warning. TODO: delete as soon as ActiveRecord is fixed
  #   ActiveRecord::Base.connection.reconnect!
  # end
  #
  # after do
  #   ActiveRecord::Base.connection.disconnect!
  # end
end
