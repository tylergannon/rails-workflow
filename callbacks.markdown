---
layout: page
permalink: /callbacks/
---

# Callback Registration

The basic expression is the same as you expect for [ActiveRecord Callbacks](http://guides.rubyonrails.org/active_record_callbacks.html#callback-registration).

```ruby
class Article < ApplicationRecord
  before_transition :set_requesting_user

  workflow do
    # ...
  end

  private
  def set_requesting_user
    self.transition_requested_by = User.first
  end
end
```

You can also do the same thing with a block:

```ruby
class Article < ApplicationRecord
  before_transition do
    self.transition_requested_by = User.first
  end

  workflow do
    # ...
  end
end
```

# Available Callbacks

The following callback types are available and they run in the order shown:

* before_transition, around_transition
* before_exit, around_exit
* before_enter, around_enter
* after_enter
* after_exit
* after_transition

# Callback Conditions

Each callback can be made to run under particular conditions using the `:if` and
`:unless` options.

```ruby
before_transition :do_something, if: :should_do_something?
before_transition :do_something, unless: :shouldnt_do_that?
```

`:if` and `:unless` can be a string, proc or method (which will be evaluated in the context
  of the object), or else a mixed array of these.

## Selecting Transitions

Each transition class has a set of arguments that determine when it will run.

### On Transition Callbacks

Use `:only` and `:except` on `before_transition` to cause a callback to run only for events whose
names match (or don't match):

```ruby
before_transition :notify_user, only: :submit
before_transition :notify_admins, only: [:reject, :report_issue]
after_transition :compile_markdown, except: :reject
```

### On Enter Callbacks

Here, `:only` and `:except` refer to the target state name for transitions.

```ruby
before_enter :notify_user, only: :submitted
```

### On Exit Callbacks

`:only` and `:except` refer here to the name of the state being exited.

```ruby
after_exit :notify_admins, only: :created
```


# Callback Arguments

This example leaves something to be desired.  How would the model know which user
requested the transition?  We have an answer for that.  Just give your method or block
a parameter and then pass the user as an argument to the transition:

```ruby
class Arcticle < ApplicationRecord
  before_transition :set_requesting_user

  workflow do
    state :created do
      on :submit, to: :submitted
    end
    state :submitted
  end

  private
  def set_requesting_user(user)
    self.transition_requested_by = user
  end
end

anArticle.submit! current_user
```
See [Callback Arguments]({{ site.baseurl }}/callback_arguments) for more on
how to pass information to your callbacks.


# Around Callbacks

Around callbacks allow you to create a context around the rest of the callback chain:

```ruby
around_transition :wrap_in_transaction

# Or,
around_transition do |object, callbacks|
  self.class.transaction do
    callbacks.call
  end
end

private
def wrap_in_transaction
  self.class.transaction do
    yield
  end
end
```

# Prepending Callbacks

To put a callback at the front of the chain:

```ruby
prepend_before_transition :do_something
```

Prepended callbacks run in the reverse order that they were registered in.

# Skipping Callbacks

* skip_before_transition
* skip_around_exit
* etc...

```ruby
before_transition :do_something
skip_before_transition :do_something, if: :shouldnt_do_something?
```

Because of the difficulty of comparing two different blocks, callbacks can only
be skipped if registered using a method name.  The above trivial example could be
solved a better way, but skipping callbacks is useful if a large class hierarchy
all requires a particular callback, and a small number of classes do not use it.
