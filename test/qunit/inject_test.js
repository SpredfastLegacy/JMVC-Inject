module("inject",{
	setup: function() {
		$('#testContent').html($('#testHtml').text());
	}
});

test("injecting functions", function(){
	expect(1);

	var injector = inject({
		name: 'foo',
		factory: inject.require('bar',function(bar) {
			return bar.baz;
		})
	},{
		name: 'bar',
		factory: function() {
			return {baz:123};
		}
	});

	injector('foo',function(foo) {
		equals(foo,123);
	})();
});

test("async dependencies", function(){

	expect(1);

	var injector = inject({
		name: 'foo',
		factory: inject.require('bar',function(bar) {
			var def = $.Deferred();
			setTimeout(function() {
				def.resolve(bar.baz);
			},200);
			return def;
		})
	},{
		name: 'bar',
		factory: function() {
			var def = $.Deferred();
			setTimeout(function() {
				def.resolve({baz:123});
			},200);
			return def;
		}
	});

	stop();
	injector('foo',function(foo) {
		equals(foo,123);
		start();
	})();

});

test("injecting methods", function(){

	var injector = inject({
		name: 'foo',
		factory: function() {
			var def = $.Deferred();
			setTimeout(function() {
				def.resolve({bar:123});
			},200);
			return def;
		}
	},{
		name: 'TestClass',
		inject: {
			thing: 'foo'
		}
	});

	$.Class('TestClass',{},{
		foo: injector('thing',function(thing) {
			equals(thing.bar,123);
			start();
		})
	});

	stop();
	new TestClass().foo();

	delete window.TestClass;
});


test("injecting controller methods scoped by selector", function(){

	expect(2);

	var injector = inject({
		name: 'foo',
		factory: function() {
			var def = $.Deferred();
			setTimeout(function() {
				def.resolve({bar:123});
			},200);
			return def;
		}
	},{
		name: 'bar',
		factory: function() {
			return {bar:456};
		}
	},{
		name: 'TestController',
		inject: {
			thing: 'foo'
		}
	},{
		name: 'TestController',
		controller: '.testThing2',
		inject: {
			thing: 'bar'
		}
	});

	$.Controller('TestController',{},{
		init: injector('thing',function(foo) {
			this.element.html(foo.bar);
			finish();
		})
	});

	stop();

	var i = 0;
	$('.testThing').test();
	$('.testThing2').test();

	function finish() {
		if(++i >= 2) {
			equals($('.testThing').html(),'123');
			equals($('.testThing2').html(),'456');
			start();
		}
	}

	delete window.TestController;
});


test("options substitution", function(){

	var injector = inject({
		name: 'foo',
		factory: function() {
			var def = $.Deferred();
			setTimeout(function() {
				def.resolve({bar:123});
			},200);
			return def;
		}
	});

	$.Controller('TestController2',{
		defaults: {
			thing: 'foo'
		}
	},{
		init: injector('{thing}',function(foo) {
			equals(foo.bar,123);
			start();
		})
	});

	stop(500);
	$('.testThing').test2();

	delete window.TestController2;
});

test("parameterized factories", function(){

	var injector = inject({
		name: 'foo()',
		factory: function(input) {
			var def = $.Deferred();
			setTimeout(function() {
				def.resolve({bar:123+input});
			},200);
			return def;
		}
	},{
		name: 'TestController3',
		inject: {
			thing: 'foo(blah)'
		}
	});

	$.Controller('TestController3',{
		defaults: {
			blah: 111
		}
	},{
		init: injector('thing',function(foo) {
			equals(foo.bar,234);
			start();
		})
	});

	stop(500);
	$('.testThing').test3();

	delete window.TestController3;
});

test("singleton: false", function(){
	var requested = false,
		calls = 0,
		injector = inject({
		name: 'foo',
		singleton: false,
		factory: function(input) {
			return ++calls;
		}
	});

	injector('foo',function(i) { equals(i,1); })();
	injector('foo',function(i) { equals(i,2); })();
	injector('foo',function(i) { equals(i,3); })();
});

test("clearCache", function(){
	var singleton = inject.cache();
	var requested = false,
		calls = 0,
		injector = inject({
		name: 'foo',
		singleton: true,
		factory: singleton('foo',function(input) {
			return ++calls;
		})
	});

	injector('foo',function(i) { equals(i,1); })();
	injector('foo',function(i) { equals(i,1); })();
	singleton.clear('foo');
	injector('foo',function(i) { equals(i,2); })();
});

test("eager: true", function(){
	expect(2);

	var singleton = inject.cache();
	var requested = false,
		injector = inject({
		name: 'foo',
		eager: true,
		factory: singleton('foo',function(input) {
			ok(!requested,'created before request');
			return 123;
		})
	});

	requested = true;
	injector('foo',function(foo) {
		equals(123,foo);
	})();
});

test("context sharing", function(){
	var singleton = inject.cache();
	var shared = inject({
		name: 'sharedFoo',
		factory: singleton('sharedFoo',function() {
			return {qux:987};
		})
	});

	// sharing context is as simple as using the shared context to inject
	// factories in another context
	var contextA = inject({
		name: 'bar',
		factory: shared('sharedFoo',function(foo) {
			return {bar:foo};
		})
	});

	var contextB = inject({
		name: 'foo',
		// the shared context can be used as a factory in another context
		factory: shared('sharedFoo',function(foo){ return foo; })
	},{
		name: 'baz',
		factory: inject.require('foo',function(foo) {
			return {baz:foo};
		})
	},{
		name: 'foo2',
		factory: function() {
			return {qux:654};
		}
	},{
		name: 'multipleContexts',
		// you can also mix other contexts with the current context
		// however, inject.require() must be on the outside if you want it to inject from the injector being defined
		// note the resulting order of the arguments
		factory: inject.require('foo2',shared('sharedFoo',function(foo,foo2) {
			return String(foo.qux) + String(foo2.qux);
		}))
	});

	contextA('bar',function(bar) {
		equals(bar.bar.qux,987);
	})();

	contextB('baz',function(baz) {
		equals(baz.baz.qux,987);
	})();

	contextB('multipleContexts',function(result) {
		equals(result,'987654');
	})();

});

test("setting the context", function(){
	var injector = inject({
		name: 'foo',
		factory: function() { return 123; }
	});
	var injector2 = inject({
		name: 'foo',
		factory: function() { return 456; }
	});

	inject.useInjector(injector,function() {
		inject.require('foo',function(foo) {
			equals(foo,123);
			inject.useInjector(injector2,function() {
				inject.require('foo',function(foo2) {
					equals(foo2,456);
				})();
			})();
		})();
	})();
});

test("capturing the current context", function(){
	var injector = inject({
		name: 'foo',
		factory: function() { return 123; }
	});

	stop();
	inject.useInjector(injector,function() {
		setTimeout(inject.useCurrent(inject.require('foo',function(foo) {
			equals(foo,123);
			start();
		})),200);
	})();
});

test("error on no context", function(){
	expect(1);
	try {
		inject.require('foo',function(foo2) {
			ok(false);
		})();
	} catch(expected) {
		ok(true,'error');
	}
});

test("context inside a named function", function(){
	var injector = inject({
		name: 'foo',
		factory: function() { return 123; }
	},{
		name: 'bar',
		inject: {
			foo: 'baz'
		}
	},{
		name: 'baz',
		factory: function() { return 456; }
	});

	injector.named('bar')('foo',function(foo) {
		equals(foo,456);
		inject.require('foo',function(realFoo) {
			equals(realFoo,123);
		})();
	})();
});
