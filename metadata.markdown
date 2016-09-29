---
layout: page
permalink: /metadata/
---

# State and Event Metadata

Place your workflow states into groups by tagging them.
Also note the helper methods `initial?` and `terminal?`.

```ruby
class Foo
  include Workflow

  state :new, tags: :bar, css_class: 'bg-primary' do
    on :complete, to: :completed, css_class: 'bg-success'
    on :cancel, to: :cancelled, css_class: 'bg-warning'
  end
  state :completed, tags: [:awesome, :congrats], css_class: 'bg-success'
  state :cancelled, css_class: 'bg-danger'
end

a = Foo.new
a.current_state.css_class
# => 'bg-primary'
a.current_state.events.first.css_class
# => 'bg-success'
```
