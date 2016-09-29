---
layout: default
---

#  Rails Workflow


Rails Workflow began as a fork of the [Workflow](https://github.com/geekq/workflow) gem by
[Vladimir Dobriakov](http://www.mobile-web-consulting.de).  It is a nearly total
rewrite but maintains the same core architecture.  It is released under the [MIT License](/license).

## What's different

* Use of [ActiveSupport::Callbacks](http://api.rubyonrails.org/classes/ActiveSupport/Callbacks.html)
to enable a more flexible application of callbacks.
* Slightly terser syntax for event definition.
* A clean way to use ActiveRecord Conditional Validation for validating whether an object is fit for the requested state transition.

# Documentation Topics

* [Getting Started]({{site.baseurl}}/getting_started)
* [Conditional State Transitions]({{ site.baseurl }}/conditional_transitions)
* [Transition Callbacks]({{ site.baseurl }}/callbacks)
* [Tagging States And Events]({{ site.baseurl }}/tags_for_states)
* [ActiveRecord Scopes]({{ site.baseurl }}/active_record_scopes)
* [State And Event Metadata]({{ site.baseurl }}/metadata)
* [Callback Arguments]({{ site.baseurl }}/callback_arguments)
* [Full API Documentation]({{ site.baseurl }}/docs)
