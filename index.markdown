---
layout: default
---

#  Rails Workflow

[https://github.com/tylergannon/rails-workflow](https://github.com/tylergannon/rails-workflow)

Rails Workflow began as a fork of the [Workflow](https://github.com/geekq/workflow) gem by
[Vladimir Dobriakov](http://www.mobile-web-consulting.de).  It is a nearly total
rewrite but maintains the same core architecture.  It is released under the [MIT License](/license).

## What's different

* Use of [ActiveSupport::Callbacks](http://api.rubyonrails.org/classes/ActiveSupport/Callbacks.html)
to enable a more flexible application of callbacks.
* Terser DSL for defining states and transitions, for enhanced readability.
* Flexible and powerful syntax for defining callbacks on state transitions
* Tighter integration with ActiveModel validations
  * Use Rails-native validations to describe conditions for allowing state transitions.
* Tighter integration with ActiveRecord
* Callback syntax patterned after ActiveRecord and ActionController callbacks
* Add `around` callbacks to wrap transitions
  * Allows wrapping transitions into an ActiveRecord transaction.
* Better metadata management
  * Instance attributes for metadata keys
  * Tagging for entity states to allow arbitrary grouping of states.

# Documentation Topics

* [Getting Started]({{site.baseurl}}/getting_started)
* [Conditional State Transitions]({{ site.baseurl }}/conditional_transitions)
* [Transition Callbacks]({{ site.baseurl }}/callbacks)
* [Tagging States And Events]({{ site.baseurl }}/tags_for_states)
* [ActiveRecord Scopes]({{ site.baseurl }}/active_record_scopes)
* [State-Specific Validations]({{ site.baseurl }}/state_specific_validations)
* [State And Event Metadata]({{ site.baseurl }}/metadata)
* [Callback Arguments]({{ site.baseurl }}/callback_arguments)
* [Full API Documentation]({{ site.baseurl }}/docs)
