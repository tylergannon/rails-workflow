---
layout: page
---

# Tagging States

Place your workflow states into groups by tagging them.
Also note the helper methods `initial?` and `terminal?`.

```ruby
class Foo
  include Workflow
  state :new, tags: :bar do
    on :complete, to: :completed
  end
  state :completed, tags: [:awesome, :congrats]
end

a = Foo.new
a.current_state.bar?
# => true
a.current_state.initial?
# => true
a.awesome?
# => false
a.transition! :complete
a.terminal?
# => true
a.awesome?
# => true
```
