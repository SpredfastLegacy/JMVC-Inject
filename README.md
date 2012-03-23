
[What is dependency injection?](https://github.com/cujojs/wire/wiki/IOC)

# Functional Dependency Injection for JavaScriptMVC

In a traditional dependency injection paradigm, the container manages objects that are connected to each other through the wiring spec. Injection is done by either setting properties or passing values to a constructor function (which typically then sets the properties on the object itself).

While that is a paradigm that works well in object oriented languages, it's more natural in a functional language like JavaScript to inject functions instead.

## Advantages of injecting functions instead of objects

 * No mutable state - no objects are modified, so it isn't possible for keys names to conflict or for injected values to be changed.
 * Late binding - dependencies do not have to be resolved until they are actually needed, so you can defer the creation of expensive objects if desired.
 * Rebinding - if the dependency to be injected changes, the next time the function is called, it will receive the new value automatically.

## Why an injector?

JMVC Inject is inspired by AMD. The reasons you'd want to inject functions are very similar to the [reasons to use an AMD loader](http://requirejs.org/docs/whyamd.html):

  * Dependencies are clearly defined.
  * Avoid global variables.
  * Identifiers can be remapped easily, so you can swap out implementations. This is great for testing and makes code more reusable.
  * Encapsulation. For functions, encapsulation means the function code can focus on producing a result instead of worrying about getting all its dependencies in order. This also makes writing [pure functions](http://en.wikipedia.org/wiki/Pure_function) a lot easier.

# Usage

To create an injector, call `Inject` with the inject and dependency definitions. The return value of `Inject` (i.e., the injector) is a function.

Injector definitions are simple objects with a `name` and a `factory` function. The factory function can return any value or it can return a [jQuery.Deferred](http://api.jquery.com/category/deferred-object/) which resolves to the value to inject. *Your factory function is called every time the dependency needs to be injected.*

In the examples, we name the injector variable `injector`, but you can call it whatever you want. e.g., `require`, `when`, `myInjector`, etc.

**NOTE:** these docs are a work in progress, but for working examples of all functionality, you can refer to the qunit tests in the test directory.

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
	var alertFoo = injector('foo',function(foo) {
		alert(foo);
	});

	alertFoo(); // alerts 6

Notice that the names passed to injector have to match the name of the dependency.

Also, your injected function will return a `Deferred`, which will resolve to the result.

## Named Functions

What if you don't know the name of the dependency you want injected or the name varies? You can name your function and use a defintion with an `inject` object to remap its dependencies:

	var injector = Inject({
		// dependency definition
		name: 'bar',
		factory: function() {
			return 2 * 3;
		}
	},{
		// inject definition
		name: 'alertFoo',
		inject: {
			foo: 'bar'
		}
	});

	var alertFoo = injector.named('alertFoo')('foo',function(foo) {
		alert(foo);
	});

	alertFoo(); // alert 6

The usefulness of named functions will become more apparent when we talk about unbound functions.

## Injecting Class methods

If you're injecting a method on a class defined with $.Class (jQueryMX),
you can inject any method in that class by using the class name.

	var injector = Inject({
		name: 'foo',
		// this example creates a Deferred manually. $.ajax and
		// all the $.Model finder methods will also return Deferreds
		factory: function() {
			var def;
			def = $.Deferred();
			setTimeout(function() {
				return def.resolve({
					bar: 123
				});
			}, 200);
			return def;
		}
	}, {
		name: 'TestClass',
		inject: {
			thing: 'foo'
		}
	});

	$.Class('TestClass', {}, {
		foo: injector('thing', function(thing) {
			alert(thing.bar);
		})
	});

	new TestClass().foo(); // alerts '123'

Nothing prevents you from using named functions as methods in your class. The function name will take precedence over the class.

## Injecting Controller methods

Controller methods can be injected just like any other class method, but also offer two additional features:

 1. Your injector defintion can include a selector, to inject controllers differently depending upon their place in the DOM.
 2. The controller options can be used to define dependencies and as arguments to parameterized factories (see below).

### Option Substitution

	var injector = Inject({
	  name: 'foo',
	  factory: function() {
		return 123;
	  }
	},{
	  name: 'bar',
	  factory: function() {
		return 456;
	  }
	});

	$.Controller('TestController2', {
	  defaults: {
		thing: 'foo'
	  }
	}, {
	  init: injector('{thing}', function(foo) {
		alert(foo);
	  })
	});

	$('.selector123').test2(); //alerts 123
	$('.selector456').test2({thing:'bar'}); //alerts 456

### Inject by Selector

	var injector = Inject({
		name: 'foo',
		factory: function() {
			return 123;
		}
	},{
		name: 'bar',
		factory: function() {
			return 456;
		}
	},{
		name: 'TestController2',
		inject: {
			thing: 'foo'
		}
	},{
		name: 'TestController2',
		selector: '.selector456',
		inject: {
			thing: 'bar'
		}
	});

	$.Controller('TestController2', {
	}, {
		init: injector('thing', function(foo) {
			alert(foo);
		})
	});

	$('.selector123').test2(); //alerts 123
	$('.selector456').test2(); //alerts 456

Using a selector, we didn't have to pass an option to the 2nd controller to inject it differently.

### Parameterized Factories

Factories used by controllers can take options as parameters, to allow for very flexible injection:

	var injector = Inject({
		name: 'foo()', // note that the name must end with ()
		// a = optionA and b = optionB below
		factory: function(a,b) {
			return a + b;
		}
	});

	$.Controller('TestController2', {
	}, {
		init:injector('foo(optionA,optionB)',function(foo) {
			alert(foo);
		})
	});

	$('.selector123').test2({
		optionA: 1,
		optionB: 2
	}); //alerts 3 (1+2)

Parameter names correspond to controller options but should not be contained in `{}`.

## Injector Context / Unbound Functions

Sometimes you need to write a function that will be used in multiple contexts. You can't use the injector directly in this case, as that would create a function that will be injected by just that injector. You need a way to create a function that can use whatever injector context it happens to be called in. This is called an unbound function.

To create an unbound function, we use `Inject.require`. Calling a bound function sets the context while that funcion is executing, so any unbound functions called within the stack of a bound function will be injected with the bound function's injector.

For `Inject.require` where the function is *called* determines which injector it uses, which is why we say it is unbound.

	var alertFoo = Inject.require('foo',function(foo) {
		alert(foo);
	});

	var injector1 = Inject({
		name: 'foo',
		factory: function() {
			return 123;
		}
	});
	var injector2 = Inject({
		name: 'foo',
		factory: function() {
			return 456;
		}
	});

	injector1(function() {
		alertFoo(); // alert 123
	})();

	injector2(function() {
		alertFoo(); // alert 456
	})();

	alertFoo();	// ERROR! No injector is available!

There is also `Inject.require.named`, which lets you create named unbound functions just like `injector.named`.

### Capturing the current context

Calling a bound function will set the context, but what about functions that need to be called outside of the stack of a bound function?

	var alertFoo = Inject.require('foo',function(foo) {
		alert(foo);
	});

	injector(function() {
		setTimeout(function() {
			alertFoo();	// ERROR! No injector is available!
		},500);
	})();

You can use `Inject.useCurrent` to define a function that will rebind the context to whatever context the function is declared in.

	injector(function() {
		setTimeout(Inject.useCurrent(function() {
			alertFoo();	// OK!
		}),500);
	})();

### Controller Action Handlers

Controllers action handlers will not generally be called inside a bound function, so they have the same problem as an async function call. Any unbound handler function has to get the injector some other way. `Inject.setupControllerActions` will setup the action handlers such that they are bound to the injector context that was active when the controller instance was created:

	$.Controller('MyController',{},{
		setup: Inject.setupControllerActions
		// OR
		setup: function() {
			// controllerSetup will call this._super, so your setup should not
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

# Misc

## Caching

Your factory function is called every time a dependency needs to be injected. If you are injecting a resource that needs to be loaded, that wont be very efficient. You'll want to cache the dependency after it is first loaded, to avoid making lots of expensive calls.

`Inject.cache` creates a helper function that will do that for you:

	var number = 1;
	var singleton = Inject.cache();
	var injector = Inject({
		name: 'foo',
		factory: singleton('foo',function() {
			return number++;
		})
	});
	alertFoo(); // alerts 1
	alertFoo(); // also alerts 1

Without the cache, the 2nd call of `alertFoo()` would have alerted 2.

The first argument to the cache function is the unique key for the cached value. You can use the key to clear the cached value at a later time so that the factory will be called again:

	singleton.clear('foo');
	alertFoo(); // alerts 2
	alertFoo(); // also alerts 2

Since your cache key will often also be the name of the dependency, the cache function has a helper that will produce the whole definition for you:

	var injector = Inject(
		singleton.def('foo',function() {
			return number++;
		})
	);

## Eager loading

If your definition includs `eager: true`, your factory will be called immediately after the injector is created. This is useful for preloading dependencies.

	var number = 1;
	var singleton = Inject.cache();
	var injector = Inject({
		name: 'foo',
		eager: true,
		factory: singleton(function() {
			return number++;
		})
	});
	// number === 2
	alertFoo(); // alerts 1, since 1 was cached

Note that you can use the `def` shortcut for eager dependencies, just pass `true` as the 3rd arugment.

## Destroying the injector

The injector has a destroy method:

    injector.destroy();

Once it is called, any function that was bound to that injector will become a noop, and functions that have been called and are waiting for dependencies to resolve will also never execute.

This is useful when you know you are done with an injector and want to cleanup any functions that may have been bound to it.

