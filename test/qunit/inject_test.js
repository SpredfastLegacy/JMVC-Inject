module("inject");

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
