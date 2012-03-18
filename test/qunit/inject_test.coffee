module "inject",
	setup: ->
		$('#testContent').html($('#testHtml').text())

test "injecting functions", ->
	expect(1)

	injector = inject({
		name: 'foo'
		factory: inject.require 'bar', (bar) ->
			bar.baz
	},{
		name: 'bar'
		factory: ->
			baz: 123
	})

	injector('foo',(foo) ->
		equals(foo,123)
	)();

test "async dependencies", ->
	expect(1)

	injector = inject({
		name: 'foo'
		factory: inject.require 'bar', (bar) ->
			def = $.Deferred()
			setTimeout ->
				def.resolve bar.baz
			,200
			def
	},{
		name: 'bar'
		factory: ->
			def = $.Deferred();
			setTimeout ->
				def.resolve baz:123
			,200
			def
	})

	stop()
	injector('foo',(foo) ->
		equals(foo,123)
		start()
	)();

test "injecting methods", ->

	injector = inject({
		name: 'foo'
		factory: ->
			def = $.Deferred()
			setTimeout ->
				def.resolve bar:123
			,200
			def
	},{
		name: 'TestClass'
		inject:
			thing: 'foo'
	})

	$.Class 'TestClass',{},
		foo: injector('thing', (thing) ->
			equals(thing.bar,123)
			start()
		)

	stop()
	new TestClass().foo()

	delete window.TestClass

test "injecting controller methods scoped by selector", ->
	expect(2);

	injector = inject({
		name: 'foo'
		factory: ->
			def = $.Deferred()
			setTimeout ->
				def.resolve bar:123
			,200
			def
	},{
		name: 'bar'
		factory: ->
			bar: 456
	},{
		name: 'TestController'
		inject:
			thing: 'foo'
	},{
		name: 'TestController'
		controller: '.testThing2'
		inject:
			thing: 'bar'
	})

	$.Controller 'TestController',{}
		init: injector('thing', (foo) ->
			this.element.html(foo.bar)
			finish()
		)

	stop()

	i = 0
	finish = ->
		if ++i >= 2
			equals($('.testThing').html(),'123')
			equals($('.testThing2').html(),'456')
			start()

	$('.testThing').test()
	$('.testThing2').test()

	delete window.TestController

test "options substitution", ->

	injector = inject({
		name: 'foo'
		factory: ->
			def = $.Deferred()
			setTimeout ->
				def.resolve bar:123
			,200
			def
	})

	$.Controller('TestController2',{
		defaults:
			thing: 'foo'
	},{
		init: injector '{thing}', (foo) ->
			equals(foo.bar,123)
			start()
	})

	stop(500);
	$('.testThing').test2();

	delete window.TestController2;

test "parameterized factories", ->

	injector = inject({
		name: 'foo()'
		factory: (input) ->
			def = $.Deferred()
			setTimeout ->
				def.resolve bar:123 + input
			,200
			def
	},{
		name: 'TestController3'
		inject:
			thing: 'foo(blah)'
	})

	$.Controller('TestController3',{
		defaults:
			blah: 111
	},{
		init: injector 'thing', (foo) ->
			equals(foo.bar,234)
			start()
	})

	stop(500)
	$('.testThing').test3()

	delete window.TestController3

test "singleton: false", ->
	requested = false
	calls = 0
	injector = inject
		name: 'foo'
		singleton: false
		factory: ->
			++calls

	injector('foo',(i) -> equals(i,1) )();
	injector('foo',(i) -> equals(i,2) )();
	injector('foo',(i) -> equals(i,3) )();

test "clearCache", ->
	singleton = inject.cache()
	requested = false
	calls = 0
	injector = inject
		name: 'foo'
		factory: singleton('foo', (input) -> ++calls)

	injector('foo',(i) -> equals(i,1) )();
	injector('foo',(i) -> equals(i,1) )();
	singleton.clear('foo');
	injector('foo',(i) -> equals(i,2) )();

test "eager: true", ->
	expect(2)

	singleton = inject.cache()
	requested = false
	injector = inject
		name: 'foo'
		eager: true
		factory: singleton('foo',(input) ->
			ok(!requested,'created before request')
			123
		)

	requested = true;
	injector('foo', (foo) -> equals(123,foo))();

test "context sharing", ->
	singleton = inject.cache()
	shared = inject
		name: 'sharedFoo'
		factory: singleton('sharedFoo', ->
			qux:987
		)

 	###
	sharing context is as simple as using the shared context to inject
	factories in another context
	###
	contextA = inject({
		name: 'bar'
		factory: shared 'sharedFoo',(foo) ->
			bar:foo
	})

	contextB = inject({
		name: 'foo'
		### the shared context can be used as a factory in another context ###
		factory: shared 'sharedFoo', (foo) -> foo
	},{
		name: 'baz'
		factory: inject.require 'foo',(foo) ->
			baz:foo
	},{
		name: 'foo2'
		factory: ->
			qux:654
	},{
		name: 'multipleContexts'
		###
			you can also mix other contexts with the current context
			however, inject.require() must be on the outside if you want it to inject from the injector being defined
			note the resulting order of the arguments
		###
		factory: inject.require('foo2',shared('sharedFoo',(foo,foo2) ->
			String(foo.qux) + String(foo2.qux)
		))
	})

	contextA('bar',(bar) ->
		equals(bar.bar.qux,987)
	)()

	contextB('baz',(baz) ->
		equals(baz.baz.qux,987)
	)();

	contextB('multipleContexts', (result) ->
		equals(result,'987654')
	)();

test "setting the context", ->
	injector = inject
		name: 'foo'
		factory: -> 123
	injector2 = inject
		name: 'foo'
		factory: -> 456

	injector( ->
		inject.require('foo',(foo) ->
			equals(foo,123)
			injector2(->
				inject.require('foo',(foo2) ->
					equals(foo2,456);
				)();
			)();
		)();
	)();

test "capturing the current context", ->
	injector = inject
		name: 'foo'
		factory: -> 123

	stop()
	injector( ->
		setTimeout(inject.useCurrent(inject.require('foo',(foo) ->
			equals(foo,123)
			start()
		)),200)
	)()

test "error on no context", ->
	expect(1)
	try
		inject.require('foo',(foo2) ->
			ok(false)
		)()
	catch expected
		ok(true,'error')

test "context inside a named function", ->
	injector = inject({
		name: 'foo'
		factory: -> 123
	},{
		name: 'bar',
		inject:
			foo: 'baz'
	},{
		name: 'baz'
		factory: -> 456
	})

	injector.named('bar')('foo',(foo) ->
		equals(foo,456)
		inject.require('foo',(realFoo) ->
			equals(realFoo,123)
		)()
	)()

test "setupControllerActions", ->
	expect(4)

	injector1 = inject({
		name: 'foo'
		factory: -> 123
	},{
		name: 'bar',
		factory: -> 456
	})

	injector2 = inject({
		name: 'foo'
		factory: -> 321
	},{
		name: 'bar',
		factory: -> 654
	})

	$.Controller('TestController4',{},{
		### this is the important part ###
		setup: inject.setupControllerActions,
		".foo click": inject.require('foo', (foo)->
			equals(foo,expected)
		),
		".bar click": inject.require('bar', (bar)->
			equals(bar,expected)
		)
	})

	injector1(-> $('.testThing3').test4() )();
	injector2(-> $('.testThing4').test4() )();

	expected = 123;
	$('.testThing3 .foo').click()
	expected = 456;
	$('.testThing3 .bar').click()

	expected = 321;
	$('.testThing4 .foo').click()
	expected = 654;
	$('.testThing4 .bar').click()

