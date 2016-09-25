---
layout: page
title: About
permalink: /about/
---

Rails Workflow began as a fork of the [Workflow](https://github.com/geekq/workflow) gem by
[Vladimir Dobriakov](http://www.mobile-web-consulting.de).  It is a nearly total
rewrite but maintains the same core architecture.  It is released under the [MIT License](/license).

## What's different

* Use of [ActiveSupport::Callbacks](http://api.rubyonrails.org/classes/ActiveSupport/Callbacks.html)
to enable a more flexible application of callbacks.
* Slightly terser syntax for event definition.
* A clean way to use ActiveRecord Conditional Validation for validating whether an object is fit for the requested state transition.
