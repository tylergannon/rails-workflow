What is workflow?
-----------------

This Gem is a fork of Vladimir Dobriakov's [Workflow Gem](http://github.com/geekq/workflow).  Credit goes to him for the inspiration, architecture and basic syntax.

## What's different in rails-workflow

* Use of [ActiveSupport::Callbacks](http://api.rubyonrails.org/classes/ActiveSupport/Callbacks.html)
to enable a more flexible application of callbacks.
* Slightly terser syntax for event definition.
* Cleaner support for using conditional ActiveRecord validations to validate state transitions.


## Installation

    gem install rails-workflow

## Configuration

No configuraion is required, but the following configurations can be placed inside an initializer:

```ruby
# config/initializers/workflow.rb
Workflow.configure do |config|
  #  Set false to avoid the extra call to the database, if you'll be saving the object after transition.
  self.persist_workflow_state_immediately = true
  #  Set true to also change the `:updated_at` during state transition.
  self.touch_on_update_column = false
end

```

Ruby Version
--------

I've only tested with Ruby 2.3.  ;)  

# Basic workflow definition:

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

## Invoking State Transitions

You may call the method named for the event itself, or else the more generic `process_event!` method

```ruby
a = Article.new
a.current_state.name
# => :new
a.submit!
a.current_state.name
# => :awaiting_review
# ... etc
```

```ruby
a = Article.new
a.process_event! :submit
a.current_state.name
# => :awaiting_review
```

The transition will return a truthy value if it succeeds: either the return value
of the event-specific callback, if one is defined, or else the name of the new state

```ruby
puts a.process_event!(:submit)
# => :awaiting_review
```

If the transition does not finish and no exception is raised, the method returns `false`.

Generally this would be because of a validation failure, so checking the model for errors
would be the next course of action.

You can also pass arguments to the event, though nothing will happen with them except
as you've defined in your callbacks (described below)

```ruby
a.submit!(author: 'Fanny Schmittenbauer', awesomeness: 29)
```

Access an object representing the current state of the entity,
including available events and transitions:

```ruby
article.current_state
# => <State name=:new events(1)=[<Event name=:submit transitions(1)=[<to=<State name=:awaiting_review events(1)=[<Event name=:review transitions(1)=...
```

On Ruby 1.9 and above, you can check whether a state comes before or
after another state (by the order they were defined):

```ruby
article.current_state
# => being_reviewed
article.current_state < :accepted
# => true
article.current_state >= :accepted
# => false
article.current_state.between? :awaiting_review, :rejected
# => true
```
Now we can call the submit event, which transitions to the
<tt>:awaiting_review</tt> state:

    article.submit!
    article.awaiting_review? # => true

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

Callbacks
-------------------------

The DSL syntax here is very much similar to ActionController or ActiveRecord callbacks.

Three classes of callbacks:

* :transition callbacks representing named events.
  * `before_transition only: :submit`
  * `after_transition except: :submit`
* :exit callbacks that match on the state the transition leaves
  * `before_exit only: :being_reviewed  #will run on the :accept or the :reject event`
* :enter callbacks that match on the target state for the transition
  * `before_enter only: :being_reviewed`  #will run on the :review event

Callbacks run in this order:

* `before_transition`, `around_transition`
  * `before_exit`, `around_exit`
    * `before_enter`, `around_enter`
      * **State Transition**
    * `after_enter`
  * `after_exit`
* `after_transition`

Within each group, the callbacks fire in the order they are set.

### Halting callbacks
Inside any `:before` callback, you can halt the callback chain:

```ruby
before_enter do
  throw :abort
end
```

Note that this will halt the callback chain without an error,
so you won't get an exception in your `on_error` block, if you have one.

## Around Transition

Allows you to run code surrounding the state transition.

```ruby
around_transition :wrap_in_transaction

def wrap_in_transaction(&block)
  Article.transaction(&block)
end
```

You can also define the callback using a block:

```ruby
around_transition do |object, transition|
  object.with_lock do
    transition.call
  end
end
```

## before_transition

Allows you to run code prior to the state transition.
If you `halt` or `throw :abort` within a `before_transition`, the callback chain
will be halted, the transition will be canceled and the event action
will return false.

```ruby
  before_transition :check_title

    def check_title
      halt('Title was bad.') unless title == "Good Title"
    end
```

Or again, in block expression:

```ruby
    before_transition do |article|
      throw :abort unless article.title == "Good Title"
    end
```
## After Transition

Runs code after the transition.

```ruby
    after_transition :check_title
```

## Prepend Transitions

To add a callback to the beginning of the sequence:

```ruby
prepend_before_transition :some_before_transition
prepend_around_transition :some_around_transition
prepend_after_transition :some_after_transition
```

## Skip Transitions

```ruby
    skip_before_transition :some_before_transition
```


## Conditions

### if/unless

The callback will run `if` or `unless` the named method returns a truthy value.

```ruby
before_transition :do_something, if: :valid?

# Array conditions apply if all aggregated conditions apply.
before_transition :do_something, if: [:valid?, :kosher?]
before_transition :do_something, if: [:valid?, "title == 'Good Title'"]
before_transition :do_something, unless: [:valid?, -> {title == 'Good Title'}]
```

### only/except

The three callback classes accept `:only` and `:except` parameters, and treat them slightly differnetly.

    You can use `:only` and `:except` in conjunction with `:if` and `:unless`.

* **Transition Callbacks** match on the name of the event being executed.
  * `before_transition only: :submit` will run when the `:submit` event is fired
  * `before_transition except: [:submit, :reject]` will run on any event except the two named
* **Exit Callbacks** match on the name of the state being exited
  * `before_exit only: :new` will run when an event causes the object to leave the `:new` state.
* **Enter Callbacks** match on the name of the state being entered
  * `before_enter only: [:cancelled, :rejected]` will run when an event leaves the object `:cancelled` or `:rejected`.

## Catching Errors

```ruby
class WorkflowModel
  include Workflow

  #  Some possibilities:
  on_error StandardError, rescue: "self.errors << 'oops!'"
  on_error StandardError, rescue: :notify_error_service!

  #  Default error class is Exception
  on_error unless: "logger.nil?" do |ex|
    logger.warn ex.message
    raise ApplicationError.new('Whoopsies!')
  end

  on_error ensure: ->{self.always_run_this!}, only: :process

  on_error SomeAppError, ensure: ->{self.always_run_this!} do |ex|
    # SomeAppError and its subclasses will be rescued and this block will run.
    # The ensure proc will be run in the ensure block.
    logger.debug "Couldn't complete transition: #{transition_context.event} because: #{ex.message}"  
  end

  workflow do
    state :initial do
      on :process, to: :processing
      on :different_process, to: :processing
    end
    state :processing do
      on :finish, to: :done
    end
    state :done
  end
end
```

## Ensuring code will run

```ruby

#  This will happen no matter what, whenever the process! event is run.
ensure_after_transitions only: :process do
  self.messages << :foo
end

ensure_after_transitions :clean_up_resources!

```

## Conditional Validations

If you are using `ActiveRecord`, you'll have access to a set of methods which
describe the current transition underway.

Inside the same Article class which was begun above, the following three
validations would all run when the `submit` event is used to transition
from `new` to `awaiting_review`.

```ruby
validates :title, presence: true, if: :transitioning_to_awaiting_review?
validates :body, presence: true, if: :transitioning_from_new?
validates :author, presence: true, if: :transitioning_via_event_submit?
```

### Halting if validations fail

    #  This will create a transition callback which will stop the event
    #  and return false if validations fail.

    halt_transition_unless_valid!

    #  This is the same as doing

    before_transition do
      throw :abort unless valid?
    end

### Checking A Transition

Call `can_transition?` to determine whether the validations would pass if a
given event was called:

```ruby
if article.can_transition?(:submit)
  #  Do something interesting
end
```

# Transition Context

During transition you can refer to the `transition_context` object on your model,
for information about the current transition.  See [Workflow::TransitionContext].

## Naming Event Arguments

If you will normally call each of your events with the same arguments, the following
will help:

```ruby
class Article < ApplicationRecord
  include Workflow

  before_transition :check_reviewer

  def check_reviewer
    # Ability is a class from the cancan gem: https://github.com/CanCanCommunity/cancancan
    halt('Access denied') unless Ability.new(transition_context.reviewer).can?(:review, self)
  end

  workflow do
    event_args :reviewer, :reviewed_at
    state :new do
      on :review, to: :reviewed
    end
    state :reviewed
  end
end
```

Transition event handler
------------------------

You can define a method with the same name as the event. Then it is automatically invoked
when event is raised. For the Article workflow defined earlier it would
be:

```ruby
class Article
  def reject
    puts 'sending email to the author explaining the reason...'
  end
end
```

`article.review!; article.reject!` will cause state transition to
`being_reviewed` state, persist the new state (if integrated with
ActiveRecord), invoke this user defined `reject` method and finally
persist the `rejected` state.


You can also define event handler accepting/requiring additional
arguments:

```ruby
class Article
  def review(reviewer = '')
    puts "[#{reviewer}] is now reviewing the article"
  end
end

article2 = Article.new
article2.submit!
article2.review!('Homer Simpson') # => [Homer Simpson] is now reviewing the article
```

Integration with ActiveRecord
-----------------------------

Workflow library can handle the state persistence fully automatically. You
only need to define a string field on the table called `workflow_state`
and include the workflow mixin in your model class as usual:

```ruby
class Order < ActiveRecord::Base
  include Workflow
  workflow do
    # list states and transitions here
  end
end
```

On a database record loading all the state check methods e.g.
`article.state`, `article.awaiting_review?` are immediately available.
For new records or if the `workflow_state` field is not set the state
defaults to the first state declared in the workflow specification. In
our example it is `:new`, so `Article.new.new?` returns true and
`Article.new.approved?` returns false.

At the end of a successful state transition like `article.approve!` the
new state is immediately saved in the database.

You can change this behaviour by overriding `persist_workflow_state`
method.

### Scopes

Workflow library also adds automatically generated scopes with names based on
states names:

```ruby
class Order < ActiveRecord::Base
  include Workflow
  workflow do
    state :approved
    state :pending
  end
end

# returns all orders with `approved` state
Order.with_approved_state

# returns all orders with `pending` state
Order.with_pending_state
```

### Wrap State Transition in a locking transaction

Wrap your transition in a locking transaction to ensure that any exceptions
raised later in the transition sequence will roll back earlier changes made to
the record:

```ruby
class Order < ActiveRecord::Base
  include Workflow

  wrap_transition_in_transaction!
  # which is the same as the following:

  around_transition do |model, transition|
    model.with_lock do
      transition.call
    end
  end

  workflow do
    state :approved
    state :pending
  end
end
```

Accessing your workflow specification
-------------------------------------

You can easily reflect on workflow specification programmatically - for
the whole class or for the current object. Examples:

```ruby
article2.current_state.events # lists possible events from here

Article.workflow_spec.states.map &:name
#=> [:rejected, :awaiting_review, :being_reviewed, :accepted, :new]

# list all events for all states
Article.workflow_spec.states.map(&:events).flatten
```

You can also store and later retrieve additional meta data for every
state and every event:

```ruby
class MyProcess
  include Workflow
  workflow do
    state :main, meta: {importance: 8} do
      on :change, to: :supplemental, meta: {whatever: true}
    end
    state :supplemental, meta: {importance: 1}
  end
end
puts MyProcess.workflow_spec.find_state(:supplemental).meta[:importance] # => 1
```

Earlier versions
----------------

The `workflow` gem is the work of Vladimir Dobriakov, <http://www.mobile-web-consulting.de>, <http://blog.geekq.net/>.

This project is a fork of his work, and the bulk of the workflow specification code
and DSL are virtually unchanged.


About
-----
Author: Tyler Gannon [https://github.com/tylergannon]

Original Author: Vladimir Dobriakov, <http://www.mobile-web-consulting.de>, <http://blog.geekq.net/>

Copyright (c) 2010-2014 Vladimir Dobriakov, www.mobile-web-consulting.de

Copyright (c) 2008-2009 Vodafone

Copyright (c) 2007-2008 Ryan Allen, FlashDen Pty Ltd

Based on the work of Ryan Allen and Scott Barron

Licensed under MIT license, see the MIT-LICENSE file.
