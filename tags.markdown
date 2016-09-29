---
layout: page
permalink: /tags_for_states/
---

# Tagging States And Events

Place your workflow states into groups by tagging them.
Also note the helper methods `initial?` and `terminal?`.

```ruby
class Foo
  include Workflow
  state :new, tags: :bar do
    on :complete, to: :completed, tags: [:feedback]
    on :cancel, to: :cancelled, tags: :bad
  end
  state :completed, tags: [:awesome, :congrats]
  state :cancelled
end

a = Foo.new
a.current_state.bar?
# => true
a.current_state.initial?
# => true
a.current_state.events.first.feedback?
# => true
a.current_state.events.first.bad?
# => false
a.awesome?
# => false
a.transition! :complete
a.terminal?
# => true
a.awesome?
# => true
```
