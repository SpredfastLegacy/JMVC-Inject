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

});


test("injecting controller methods scoped by selector", function(){

});
