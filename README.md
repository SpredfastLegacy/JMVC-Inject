
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

To create an injector, call `Inject` with the injection definitions. The return value of `Inject` is a function that is the injector.

Injector definitions are simple objects with a `name` and a `factory` function. The factory function can return any value or it can return a [jQuery.Deferred](http://api.jquery.com/category/deferred-object/) which resolves to the value to inject.

In the examples, we name the injector variable `injector`, but you can call it whatever you want. e.g., `require`, `when`, `myInjector`, etc.

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
	var alertFoo = injector('foo',function(foo) {
		alert(foo);
	});

	alertFoo(); // alerts 6

Notice that the names passed to injector have to match the name of the factory.

Also, your injected function will return a `Deferred`, which will resolve to the result.

## Named Functions

What if you don't know the names of the factory you want injected or the names vary?

	var injector = Inject({
		name: 'bar',
		factory: function() {
			return 2 * 3;
		}
	},{
		name: 'alertFoo',
		inject: {
			foo: 'bar'
		}
	});

	var alertFoo = injector.named('alertFoo')('foo',function(foo) {
		alert(foo);
	});

	alertFoo(); // alert 6

## Injecting Class methods

If you're injecting a method on a class defined with $.Class (jQueryMX),
you can inject any function in that class by using the class name.

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

## Injecting Controller methods

Controllers can be injected just like any other class, but also offer two additional features:

 1. Your injector defintion can include a selector, to inject controllers differently depending upon their place in the DOM.
 2. The controller options can be used to define dependencies and as arguments to parameterized factories (see below).

### Option Susbtitution

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

## Injector Context

Sometimes you need to write a function that will be used in multiple contexts. You can't use the injector directly in this case, as that would create a function that will be injected by just that injector. You need a way to create a function that can use whatever injector context it happens to be called in.

To create an unbound injected function, we use `Inject.require`. Calling an injected function sets the context while that funcion is executing, so any `Inject.require` functions called within an injected function will inherit the injector.

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

For `Inject.require` where the function is *called* determines which injector it uses.

### Capturing the current context

Calling an injector function will set the context, but what about functions that need to be called outside of an injector function?

	var alertFoo = Inject.require('foo',function(foo) {
		alert(foo);
	});

	injector(function() {
		setTimeout(function() {
			alertFoo();	// ERROR! No injector is available!
		},500);
	})();

You can use `Inject.useCurrent` to define a function that will reset the context to whatever context the function is declared in.

	injector(function() {
		setTimeout(Inject.useCurrent(function() {
			alertFoo();	// OK!
		}),500);
	})();

### Controller Action Handlers

Controllers action handlers will not generally be called inside an injected function, so they have the same problem as an async function call. Any handler using `Inject.when` has to get the injector some other way. `Inject.setupControllerActions` will setup the action handlers such that they use the injector context that was active when the controller was created:

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

# Helpers

## Caching

	TODO

## Eager loading

	TODO
