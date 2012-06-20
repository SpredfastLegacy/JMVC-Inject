
[What is dependency injection?](https://github.com/cujojs/wire/wiki/IOC)

# Functional Dependency Injection for JavaScriptMVC (DoneJS/CanJS)

In a traditional dependency injection paradigm, the container manages objects that are connected to each other through the wiring spec. Injection is done by either setting properties or passing values to a constructor function (which typically then sets the properties on the object itself).

While that is a paradigm that works well in object oriented languages, it's more natural in a functional language like JavaScript to inject functions instead.

**NOTE:** inject-core.js can be used independently of JavaScript MVC. You obviously wont be able to use the Class and Controller based functionality, but named functions and everything else should work.

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

## New Features

 * Injecting Controller options - Controllers can have their options set to injected values. Controller instantiation will be deferred.
 * Injecting Attributes - Like controllers, Model/Observe style Classes can have their attributes set with values from the injector (but creation will be deferred).

# Usage

To create an injector, call `Inject` with the inject and dependency definitions. The return value of `Inject` (i.e., the injector) is a function.

Injector definitions are simple objects with a `name` and a `factory` function. The factory function can return any value or it can return a [jQuery.Deferred](http://api.jquery.com/category/deferred-object/) which resolves to the value to inject. *Your factory function is called every time the dependency needs to be injected.*

In the examples, we name the injector variable `injector`, but you can call it whatever you want. e.g., `require`, `when`, `myInjector`, etc. The injector is also referred to as the context.

**NOTE:** these docs are fairly complete, but you can always find working examples in the qunit tests in the test directory.

## Injecting plain functions

	var injector = Inject({
		name: 'foo',
		factory: function() {
			// your factory function can do anything. if you need to make ajax calls or use
			// a web worker or something, just return a jQuery.Deferred
			return 2 * 3;
		}
	},{
		name: 'bar',
		// this example creates a Deferred manually. $.ajax and
		// all the $.Model finder methods will also return Deferreds
		factory: function() {
			var def;
			def = $.Deferred();
			setTimeout(function() {
				return def.resolve(123);
			}, 200);
			return def;
		}
	});

	// pass injector the list of dependencies and the function to inject
	var alertFoo = injector('foo',function(foo) {
		alert(foo);
	});

	alertFoo(); // alerts 6

	var alertBar = injector('bar',function(bar) {
		// notice that bar is the result of the deferred,
		// you never have to deal with a deferred directly
		alert(bar);
		return 'result';
	});

	alertBar(); // alerts 123

	// your injected function always returns a Deferred
	alertBar().then(function(result) {
		alert(result); // alerts 'result'
	});

Notice that the names passed to injector have to match the name of the dependency.

Also, your injected function will return a `Deferred`, which will resolve to the result.

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

Note that `useCurrent` will throw an exception if there is no current context. If you want to capture the context if there is one, but otherwise proceed as normal, then pass `true` as the second argument.

### Controller Action Handlers

Controllers action handlers will not generally be called inside a bound function, so they have the same problem as an async function call. Any unbound handler function has to get the injector some other way. `Inject.setupController` will setup the action handlers such that they are bound to the injector context that was active when the controller instance was created:

	$.Controller('MyController',{
		// notice this is the static part
		setup: Inject.setupController
		// OR
		setup: function() {
			// setup will call this._super, so your setup should not
			Inject.setupController.apply(this,arguments);
			// do other setup stuff
		}
	},{
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

Under the hood, all `setupController` is doing is wrapping each action with
`Inject.useCurrent`.


## Return Values & Event Handlers

By default, your injector function returns a `$.Deferred`. What if you need a different return value? This is a problem when you try to inject a click handler:

	".someLink click": Inject.require('foo',function(foo,el,event) {
		alert(foo);
		return false; // oops, this doesn't work, the link is loaded...
		// event.preventDefault() would also not work if any dependency was still loading asynchronously
	})

To fix this, use `andReturn`:

	".someLink click": Inject.require('foo',function(foo,el,event) {
		alert(foo);
	}).andReturn(false)

`andReturn` can also take a function. The function will be passed the $.Deferred from the injected function and any addtional arguments passed in (but not the injected arguments):

	".someLink click": Inject.require('foo',function(foo,el,event) {
		alert(foo);
	}).andReturn(function(deferred,el,event) {
		event.preventDefault();
	})

# Naming

This section shows how you can inject functions differently based on their name, the class they belong to, or even using the controller's position in the DOM and controller options.

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

## Injecting Class methods

If you're injecting a method on a class defined with $.Class (jQueryMX),
you can inject any method in that class by using the class name.

	var injector = Inject({
		name: 'foo',
		factory: function() {
			return {bar:123};
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

Note: Nothing prevents you from using named functions as methods in your class. The function name will take precedence over the class.

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
		name: 'foo',
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


## Injecting Constructors

### Injecting controller options

The injector can set values on the options object passed to your controller by using the `Inject.setupController` method as your static setup method. This enables templated event binding on injected values (JMVC 3.2+).

Note that the controller instance itself is not modified, just the initial options hash that is passed in and the injector will *not* override options that are already defined, because they have been passed in to the controller at the point of creation:

    $.Controller('Foo',{
        // note this is the Static setup method
        setup: Inject.setupController // also fixes controller actions
    },{
        init: function() {
        	// alerts "Hello Bob!"
            alert(this.options.foo + this.options.bar);
        },
        "{model} foo": function(model,event) {
        	// foo changed! do something!
        }
    });

    Inject({
        name: 'bar',
        factory: function() {
            return 'Hello ';
        }
    },{
        name: 'baz',
        factory: function() {
            return 'World!';
        }
    },{
    	name: 'someModel',
    	factory: // ...
    },{
        name: 'Foo',
        options: {
            foo: 'bar',
            bar: 'baz',
            model: 'someModel'
        }
    })(function() {
        $('#foo').foo({bar: 'Bob!'});
    }).call(this);

### Injecting Attributes

Similarly, classes that take a hash of attribute values as the first argument to their contructor can have injected values set.

Note that the class instance itself is not modified, just what is passed to the constuctor and the injector will *not* override values that are already defined:

    $.Observe('Foo',{
        // note this is the Static setup method
        setup: Inject.setup
    },{
        init: function() {
        	// baz = "Hello Bob!"
            this.baz = this.foo + this.bar;
        }
    });

    Inject({
        name: 'bar',
        factory: function() {
            return 'Hello ';
        }
    },{
        name: 'baz',
        factory: function() {
            return 'World!';
        }
    },{
        name: 'Foo',
        attrs: {
            foo: 'bar',
            bar: 'baz'
        }
    })(function() {
        new Foo({bar:'Bob!'}).done(function(foo) {
            alert(foo.baz);
        });
    }).call(this);

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

# Plugins

The injector has some simple but powerful support for plugins. First lets define our vocabulary:

 * __target__ - this is the `this` of the injected function. e.g.,

        foo.bar(); // if bar is injected, its target is foo

 * __definition__ - definitions are the configuration objects you passed in when creating the injector.  Plugins may produce additional definitions. All definitions are merged to create the final definition, with later definitions taking precedence. Plugin definitions are always added after the initial definitions.

You create a plugin like this:

	// plugin hooks run in the order the plugins are defined
	// all hooks are optional
    Inject.plugin({
    	/**
    	 * @param pluginSupport provides `definition(name/target)`
    	 * which returns the definition that would be used to resolve or inject
    	 * the name or the target. This is handy for getting the factory for a
    	 * dependency.
    	 * When looking up the definition of a target, keep in mind that some plugins
    	 * alter the definition based on the target's properties, so the final definition
    	 * may be different if you pass a name instead of the real target.
    	 */
        init: function(pluginSupport) {
            this.support = pluginSupport;
    		// other setup goes here
        },
        /**
         * Gives the plugin a chance to provide additional definition for a target.
         *
         * This is called each time an injected funtion is called, so make it fast!
         *
         * pluginSupport.definition calls this method, so unless you are very clever,
         * you will cause a stack overflow if you try to get other definitions
         * from this method.
         *
         * @param target the object(this) of the function being injected.
         * @param definitions an array of the definitions supplied to the injector
         * that match the target. Includes definitions created by plugins that ran
         * before this one.
         * @return an additional definition object that will override the previous
         * definitions. Or nothing if you have no overrides.
         */
        processDefinition: function(target,definitions) {
        	$.each(definitions,function() {
        		// inspect the definition object
        	});
        	// inspect the target object being injected
        	return { definition: 'overrides' };
        },
        /**
         * Gives the plugin a chance to provide its own factory function to resolve a
         * dependency. The last plugin to return a factory "wins."
         *
         * This is called every time a dependency needs to be resolved (multiple times
         * per function call), so make it fast!
         *
         * @param target the object (this) the function being injected is called on.
         * @param nameToResolve the name being resolved. This is the name after any inject
         * mapping is applied.
         * @param targetDefintion - the definition of the target.
         * @return the new factory function, or nothing to keep the original.
         */
        resolveFactory: function(target,nameToResolve,targetDefinition) {
        	// get the current definition if you need it (good for wrapping/transforming results)
        	var definition = this.support.definition(nameToResolve);

        	// inspect targetDefintion and target to determine if you want a new factory

        	return newFactoryFunction;
        }
    });

The injector core only processes `name`, `factory`, `inject` and `eager`. Any additional keys can be used as hooks by plugins. All the controller and Class enhancements are implemented via plugins.

As all plugins apply to all injectors, be sure to give your plugin hooks nice uniquely namespaced names.
