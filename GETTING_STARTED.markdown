---
layout: default
title: Getting Started
categories: documentation
permalink: /getting_started/
---
# Install

Add the following to your `Gemfile`

```ruby
gem 'rails-workflow', '~> 1.4'
```

Or install from the command line:

```ruby
gem install rails-workflow
```

# Define Your Workflow

```ruby
class Article
  include Workflow
  workflow do
    state :new do
      on :submit, to: :awaiting_review
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
  end
end

```

# Invoke State Transitions

Each named state transition (event) has an instance method(!) named after it, such as `#submit!`,
which delegates directly to the more generic  [#transition!](/docs/Workflow.html#transition%21-instance_method) method.

By default, ActiveRecord objects will immediately persist the new workflow state.

The transition will return the name of the new state, or else a `falsy` value if the
transition failed without an exception.

```ruby
a = Article.new
a.current_state.name
# => :new
puts a.submit!
# => :awaiting_review

a.awaiting_review?
# => true
```

```ruby
a = Article.new
a.transition! :submit
a.current_state.name
# => :awaiting_review
```

The transition will return a truthy value if it succeeds: either the return value
of the event-specific callback, if one is defined, or else the name of the new state

```ruby
puts a.transition!(:submit)
# => :awaiting_review
```

# Pass Arguments To Your State Transition

```ruby
a.submit!(author: 'Fanny Schmittenbauer', awesomeness: 29)
```

# Access Your Object's Current State

Access an object representing the current state of the entity,
including available events and transitions:

```ruby
article.current_state
# => <State name=:new events(1)=[<Event name=:submit transitions(1)=[<to=<State name=:awaiting_review events(1)=[<Event name=:review transitions(1)=...
article.current_state.transitions
# => ...
```
