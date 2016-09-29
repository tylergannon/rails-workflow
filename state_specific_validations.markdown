---
layout: page
permalink: /state_specific_validations/
---

# State-Specific Validations

If your class inherits from `ActiveModel::Validations` (which includes any
ActiveRecord models), the object will be validated in its new state.

If the validation fails, the object will be returned to its original state,
the method call will return a falsy value, and the errors object will contain
whatever errors resulted from the validation.

Use the overloaded comparison operators on the current state to
create conditional validations that apply only to certain states or ranges of
states:

```ruby
class Article < ApplicationRecord
  include Workflow

  validates :reviewer, presence: true, if: -> { current_state >= :reviewed }
  validates :title, presence: true, if: -> { current_state > :new }, unless: :trashed?

  workflow do
    state :new do
      on :submit, to: :submitted
    end
    state :submitted do
      on :review, to: :reviewed
    end
    state :reviewed do
      on :publish, to: :published
      on :trash, to: :trashed
    end
    state :published
    state :trashed
  end
end
```

The `valid?` method has been overridden for classes inheriting from `ActiveRecord::Base`,
such that calling `valid?` will not trigger another validation until some attribute has
been changed.

This is so that you can do something like:

```ruby
my_object.transition! :failing_transition
my_object.valid?
# => false
my_object.errors.clear
my_object.valid?
# => true
```
