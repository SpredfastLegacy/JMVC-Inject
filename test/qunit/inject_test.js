module("inject",{
	setup: function() {
		$('#testContent').html($('#testHtml').text());
	}
});

test("injecting functions", function(){
	expect(1);

	var when = injector({
		name: 'foo',
		factory: injector.when('bar',function(bar) {
			return bar.baz;
		})
	},{
		name: 'bar',
		factory: function() {
			return {baz:123};
		}
	});

	when('foo',function(foo) {
		equals(foo,123);
	})();
});

test("async dependencies", function(){

	expect(1);

	var when = injector({
		name: 'foo',
		factory: injector.when('bar',function(bar) {
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
	when('foo',function(foo) {
		equals(foo,123);
		start();
	})();

});

test("injecting methods", function(){

	var when = injector({
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
		foo: when('thing',function(thing) {
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

	var when = injector({
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
		init: when('thing',function(foo) {
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

	var when = injector({
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
		init: when('{thing}',function(foo) {
			equals(foo.bar,123);
			start();
		})
	});

	stop(500);
	$('.testThing').test2();

	delete window.TestController2;
});

test("parameterized factories", function(){

	var when = injector({
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
		init: when('thing',function(foo) {
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
		when = injector({
		name: 'foo',
		singleton: false,
		factory: function(input) {
			return ++calls;
		}
	});

	when('foo',function(i) { equals(i,1); })();
	when('foo',function(i) { equals(i,2); })();
	when('foo',function(i) { equals(i,3); })();
});

test("clearCache", function(){
	var requested = false,
		calls = 0,
		when = injector({
		name: 'foo',
		singleton: true,
		factory: function(input) {
			return ++calls;
		}
	});

	when('foo',function(i) { equals(i,1); })();
	when('foo',function(i) { equals(i,1); })();
	when.clearCache('foo');
	when('foo',function(i) { equals(i,2); })();
});

test("eager: true", function(){
	expect(2);

	var requested = false,
		when = injector({
		name: 'foo',
		eager: true,
		factory: function(input) {
			ok(!requested,'created before request');
			return 123;
		}
	});

	requested = true;
	when('foo',function(foo) {
		equals(123,foo);
	})();
});

test("reset?", function(){
	ok(false,"How do we reset? What's the right way to do it?");
});
