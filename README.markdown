# State Management for ActiveRecord Entities

For when your ActiveRecord entity passes through a number of states during the course of
a defined workflow.  This is a rewrite of Vladimir Dobriakov's [Workflow Gem](https://github.com/geekq/workflow),
rewritten to achieve:

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

https://tylergannon.github.io/rails-workflow/

2016 Tyler Gannon http://tylergannon.github.io


### Credits

Copyright (c) 2010-2014 Vladimir Dobriakov, www.mobile-web-consulting.de
Copyright (c) 2008-2009 Vodafone
Copyright (c) 2007-2008 Ryan Allen, FlashDen Pty Ltd
Based on the work of Ryan Allen and Scott Barron
Licensed under MIT license, see the MIT-LICENSE file.
