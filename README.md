
[What is dependency injection?](https://github.com/cujojs/wire/wiki/IOC)

# Functional Dependency Injection for JavaScriptMVC

In a traditional dependency injection paradigm, the container manages objects that
are connected to each other through the wiring spec. Injection is done by either setting
properties or passing values to a constructor function (which typically then sets the
properties on the object itself).

While that is a paradigm that works well in object oriented languages, it's more natural
in a functional language like JavaScript to inject functions instead.

## Advantages of injecting functions

 * No mutable state - no objects are modified, so it isn't possible for keys names to conflict
   or for inject values to be changed.
 * Late binding - dependencies do not have to be resolved until they are actually needed,
   so you can defer the creation of expensive objects if desired.
 * Rebinding - if the dependency to be injected changes, the next time the function is called,
   it will receive the new value automatically.

# Usage

To create an injector, call `inject` with the injection definitions. The return value of
`inject` is a function that is the injector.

In the examples, we name the injector variable `injector`, but you can call it whatever you want. e.g., `require`, `when`, etc.

*NOTE:* these docs are a work in progress, but for working examples of all functionality, you can refer to the qunit tests in the test directory.

## Injecting plain functions

	var injector = Inject({
		name: 'foo',
		factory: function() {
			// your factory function can do anything. if you need to make ajax calls or use
			// a web worker or something, just return a jQuery.Deferred
			return 2 * 3;
		}
	});

	// pass injector the list of dependencies and the function to inject
	var myFunc = injector('foo',function(foo) {
		alert(foo);
	});

	myFunc(); // alerts 6

Notice that the names passed to injector have to match the name of the factory.

## Named Functions

What if you don't know the names of the factory you want injected or the names vary?

	var injector = Inject({
		name: 'bar',
		factory: function() {
			// your factory function can do anything. if you need to make ajax calls or use
			// a web worker or something, just return a jQuery.Deferred
			return 2 * 3;
		}
	},{
		name: 'alertFoo',
		inject: {
			foo: 'bar'
		}
	});

    var myFunc = injector.named('alertFoo')('foo',function(foo) {
		alert(foo);
	});

	myFunc(); // alert 6

## Injecting Class methods

If you're injecting a method on a class defined with $.Class (jQueryMX),
you can inject any function in that class by using the class name.

	TODO

## Injecting Controller methods

	TODO

## Injector Context

Sometimes you need to write a function that will be used in multiple contexts.
You can't use the injector directly in this case, as that would create a function
that will be injected by just that injector. You need a way to create a function
that can use whatever injector context it happens to be called in.

### Using the current context

    alertFoo: Inject.require('foo',function(foo) {
    	alert(foo);
    })

    // ... TODO

### Setting/changing the context

Calling an injected function sets the context while that funcion is executing,
so any `Inject.require` functions called (note: not defined) within an injected
function will inherit the injector.

	var injector = Inject(...);
    injector(function() {
    	// functions like this will resolve foo from injector
    	Inject.require('foo',function(foo) {
    		// ...
    	})();
    })();

Note that while we use an injected function with no dependencies above,
any injected function will serve.

### Capturing the current context

Calling an injector function will set the context, but what about functions that need to be
called outside of an injector function? If you can't use a specific injector, you
can use `Inject.useCurrent` to create a function that will reset the context to whatever
context the function is declared in.

	setTimeout(Inject.useCurrent(function() {
		// do things
	}),500);

	TODO more

### Controller Action Handlers

Controllers action handlers will not generally be called inside an injected function,
so any handler using `Inject.when` has to get the injector some other way.
`Inject.setupControllerActions` will setup the action handlers such that they
use the injector context that was active when the controller was created:

	$.Controller('MyController',{},{
		setup: Inject.setupControllerActions
		// OR
		setup: function() {
			// controllerSetup will call this._super
			Inject.setupControllerActions.apply(this,arguments);
			// do other setup stuff
		}
	});

	var injector1 = Inject(...);
	var injector2 = Inject(...);

	injector1('foo',function() {
		// all action handlers will use injector1
		$('#content1 .myContent').my();
	});
	injector2('foo',function() {
		// all action handlers will use injector2
		$('#content2 .somethingElse').my();
	});

Under the hood, all `setupControllerActions` is doing is wrapping each action with
`Inject.useCurrent`.

