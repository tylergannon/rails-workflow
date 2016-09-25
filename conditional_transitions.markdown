---
layout: default
categories: documentation
permalink: /conditional_transitions/
---
# Multiple Possible Targets For A Given Event

The first matching condition will determine the target state.
An error will be raised if none match, so a catchall at the end is a good idea.

```ruby
class Article
  include Workflow
  workflow do
    state :new do
      on :submit do
        to :awaiting_review, if: :today_is_wednesday?
        to :being_reviewed, unless: "author.name == 'Foo Bar'"
        to :accepted, if: -> {author.role == 'Admin'}
        to :rejected, if: [:bad_hair_day?, :in_a_bad_mood?]
        to :the_bad_place
      end
    end
    state :awaiting_review do
      on :review, to: :being_reviewed
    end
    state :being_reviewed do
      on :accept, to: :accepted
      on :reject, to: :rejected
    end
    state :accepted
    state :rejected
    state :the_bad_place
  end
end
```
