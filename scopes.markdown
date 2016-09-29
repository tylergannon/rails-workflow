---
layout: page
permalink: /active_record_scopes/
---

# ActiveRecord Scopes For Your Workflow Classes

Place your workflow states into groups by tagging them.
Also note the helper methods `initial?` and `terminal?`.

```ruby
class Foo < ApplicationRecord
  include Workflow
  state :new, tags: :bar do
    on :complete, to: :completed, tags: [:feedback]
    on :cancel, to: :cancelled, tags: :bad
  end
  state :completed, tags: [:awesome, :congrats]
  state :cancelled
end

Foo.in_terminal_state
# => returns anything that's completed or cancelled
Foo.not_in_terminal_state
Foo.with_completed_state # or with_(any other state)_state
Foo.state_tagged_with(:bar, :awesome) # Anything in states with these tags
Foo.state_not_tagged_with(:bar, :awesome) # Everything else
```
