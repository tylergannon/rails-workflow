---
layout: page
permalink: /callback_arguments/
---

# Callback Arguments

You can pass any data in to your transition, and then only receive certain
arguments in your callbacks.

First, let's assume you've passed a whole bunch of data to your transition event:

```ruby
article.submit! current_user, request.user_agent, params[:time_zone],
  article_params: article_params,
  foo: :baz,
  quux: :certainly
```

You can define a keyword argument on your callback to get just one or two of the
arguments:

```ruby
before_transition :get_quux

def get_quux(quux:, foo:)
  puts quux
  # => :certainly
  puts foo
  # => :baz
end
```

Another example:

```ruby
before_transition :get_quux

def get_quux(user, *args, quux:, foo:, **attributes)
  # ...
end
```
Here, the `args` array will contain everything but the user, and `attributes` will contain `:article_params`.

# Special Keywords: event, from, to

Get the name of the event being fired, the state being exited, and/or the
state being entered, by adding any or all of those parameter names to your callback.

```ruby
def my_callback(event, from, to, current_user:)
end

# ...
my_obj.submit! current_user: current_user
```

# Block-Style Definition

To make use of this functionality on block style callbacks:

```ruby
before_transition do |current_user:|
  logger.debug(current_user.name)
end

around_transition do |object, callbacks, current_user:|
  logger.debug(current_user.name)
  callbacks.call
end
```

### Caveat: Using normal arguments on a block

Due to implementation particulars, if you're going to use normal arguments on
a before or after callback block, you must also receive a copy of the object
as the first argument to your block:

```ruby
before_transition do |object, current_user|
  object == self #  This will be true
  # ...
end

my_object.submit! current_user
```
