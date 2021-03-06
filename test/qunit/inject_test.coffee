module "inject",
	setup: ->
		$('#testContent').html($('#testHtml').text())

test "injecting functions", ->
	expect(1)

	injector = Inject({
		name: 'foo'
		factory: Inject.require 'bar', (bar) ->
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

	injector = Inject({
		name: 'foo'
		factory: Inject.require 'bar', (bar) ->
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


test "require.named", ->
	expect(1)

	injector = Inject({
		name: 'foo'
		factory: -> 456
	},{
		name: 'bar'
		factory: -> 123
	},{
		name: 'foobar',
		inject: {
			foo: 'bar'
		}
	})

	injector( ->
		Inject.require.named('foobar')('foo',(foo)->
			equals(123,foo)
		)()
	)()

test "injecting methods", ->

	injector = Inject({
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

	injector = Inject({
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

	injector = Inject({
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

	injector = Inject({
		name: 'foo'
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
	injector = Inject
		name: 'foo'
		factory: ->
			++calls

	injector('foo',(i) -> equals(i,1) )();
	injector('foo',(i) -> equals(i,2) )();
	injector('foo',(i) -> equals(i,3) )();

test "clearCache", ->
	singleton = Inject.cache()
	requested = false
	calls = 0
	injector = Inject(
		singleton.def('foo', (input)->
			++calls
		)
	)

	injector('foo',(i) -> equals(i,1) )();
	injector('foo',(i) -> equals(i,1) )();
	singleton.clear('foo');
	injector('foo',(i) -> equals(i,2) )();

test "eager: true", ->
	expect(2)

	singleton = Inject.cache()
	requested = false
	injector = Inject(
		singleton.def('foo', (input)->
			ok(!requested,'created before request')
			123
		,true)
	)

	requested = true;
	injector('foo', (foo) ->
		equals(123,foo)
	)()

test "singleton: true", ->
	calls = 0
	injector = Inject
		name: 'foo'
		singleton: true
		factory: ->
			++calls

	equals(calls,0,'singletons are not eager by default')
	injector('foo',(i) -> equals(i,1) )();
	injector('foo',(i) -> equals(i,1) )();
	injector('foo',(i) -> equals(i,1) )();

test "eager singleton", ->
	calls = 0
	injector = Inject
		name: 'foo'
		eager: true
		singleton: true
		factory: ->
			++calls

	equals(calls,1,'eager')
	injector('foo',(i) -> equals(i,1) )();
	injector('foo',(i) -> equals(i,1) )();
	injector('foo',(i) -> equals(i,1) )();

test "can avoid cache loops", ->
	expect 2
	cache = Inject.cache()
	Inject({
		name: 'foo',
		factory: Inject.require 'bar', (bar)->
			bar.foo
	},cache.def('bar',->
		bar =
			foo:123
		Inject.require('foo',(foo)->
			bar.bar = foo
		).call(this)
		bar
	))('bar',(bar)->
		equals(bar.bar,123)
		equals(bar.foo,123)
	).call(this)

test "context sharing", ->
	singleton = Inject.cache()
	shared = Inject( singleton.def('sharedFoo', ()-> qux:987) )

	###
		sharing context is as simple as using the shared context to inject
		factories in another context
	###
	contextA = Inject({
		name: 'bar'
		factory: shared 'sharedFoo',(foo) ->
			bar:foo
	})

	contextB = Inject({
		name: 'foo'
		### the shared context can be used as a factory in another context ###
		factory: shared 'sharedFoo', (foo) -> foo
	},{
		name: 'baz'
		factory: Inject.require 'foo',(foo) ->
			baz:foo
	},{
		name: 'foo2'
		factory: ->
			qux:654
	},{
		name: 'multipleContexts'
		###
			you can also mix other contexts with the current context
			however, Inject.require() must be on the outside if you want it to inject from the injector being defined
			note the resulting order of the arguments
		###
		factory: Inject.require('foo2',shared('sharedFoo',(foo,foo2) ->
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
	injector = Inject
		name: 'foo'
		factory: -> 123
	injector2 = Inject
		name: 'foo'
		factory: -> 456

	injector( ->
		Inject.require('foo',(foo) ->
			equals(foo,123)
			injector2(->
				Inject.require('foo',(foo2) ->
					equals(foo2,456);
				)();
			)();
		)();
	)();

test "retain the context", ->
	injector = Inject
		name: 'foo'
		factory: ->
			def = $.Deferred()
			setTimeout(->
				def.resolve 123
			,25)
			def

	stop(100)
	injector( ->
		Inject.require('foo',(foo) ->
			equals(foo,123)
			Inject.require('foo',(foo2) ->
				equals(foo2,123);
				start()
			)()
		)()
	)()

test "destroy the context", ->
	injector = Inject
		name: 'foo'
		factory: ->
			def = $.Deferred()
			setTimeout(->
				def.resolve 123
			,25)
			def

	stop(200)
	injector( ->
		Inject.require('foo',(foo) ->
			ok(false,'should never have run!')
		)()
	)()

	injector.destroy()

	setTimeout start, 100


test "capturing the current context", ->
	expect 2
	injector = Inject
		name: 'foo'
		factory: -> 123

	stop()
	injector( ->
		setTimeout(Inject.useCurrent('foo',(foo) ->
			equals(foo,123)
			start()
		),200)
	)()

	Inject.useCurrent(->
		ok(true,'Can ignore no context')
	,true).call this

test "error on no context", ->
	expect(1)
	try
		Inject.require('foo',(foo2) ->
			ok(false)
		)()
	catch expected
		ok(true,'error')

test "context inside a named function", ->
	injector = Inject({
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
		Inject.require('foo',(realFoo) ->
			equals(realFoo,123)
		)()
	)()

test "setupControllerActions", ->
	expect(4)

	injector1 = Inject({
		name: 'foo'
		factory: -> 123
	},{
		name: 'bar',
		factory: -> 456,
	},{
		name: 'TestController4',
		inject: {
			mapMe: 'foo'
		}
	})

	injector2 = Inject({
		name: 'foo'
		factory: -> 321
	},{
		name: 'bar',
		factory: -> 654
	},{
		name: 'TestController4',
		inject: {
			mapMe: 'foo'
		}
	})

	$.Controller('TestController4',{
		setup: Inject.setupController,
		defaults: {
			foo: 'mapMe'
		}
	},{
		### this is the important part ###
		".foo click": Inject.require('{foo}', (foo)->
			equals(foo,expected)
		),
		".bar click": Inject.require('bar', (bar)->
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

test "andReturn", ->
	expect 9

	injector = Inject({
		name: 'foo',
		factory: -> 123
	})

	equals 456, injector('foo', (foo) ->
		equals(123,foo)
	).andReturn(->456)()

	equals false, injector('foo', (foo) ->
		equals(123,foo)
	).andReturn(false)()

	injector( ->
		equals 456, Inject.require('foo', (foo) ->
			equals(123,foo)
		).andReturn(456)()
	)()


	equals false, injector('foo', (foo,bar) ->
		equals(456,bar)
	).andReturn((result,bar)->
		equals(456,bar)
		false
	)(456)


test 'injecting options', ->
	expect 1
	$.Controller('Foo',{
    	setup: Inject.setupController
	},{
		init: ->
			equals(this.options.foo + this.options.bar,'Hello Bob!')
	})

	Inject({
		name: 'bar',
		factory: -> 'Hello '
	},{
		name: 'baz',
		factory: -> 'World!'
	},{
		name: 'Foo',
		options:
			foo: 'bar',
			bar: 'baz'
	})(->
		$('.testThing').foo({bar:'Bob!'})
	).call(this)


test 'injecting attrs', ->
	expect 1
	$.Model('Foo',{
		setup: Inject.setup
	},{
		init: -> @baz = @foo + @bar
	})

	Inject({
		name: 'bar',
		factory: -> 'Hello '
	},{
		name: 'baz',
		factory: -> 'World!'
	},{
		name: 'Foo',
		attrs: {
			foo: 'bar',
			bar: 'baz'
		}
	})(->
		new Foo({bar:'Bob!'}).done (foo) ->
			equals(foo.baz,'Hello Bob!')
	).call(this);

test 'plugin onDestroy', ->
	count = 0
	Inject.plugin
		onCreate: ->
			count++
		onDestroy: ->
			count--

	equals(count,0)
	inject = Inject({})
	equals(count,1,'onCreate called')
	inject.destroy()
	equals(count,0,'onDestroy called')
	inject = Inject({})
	inject2 = Inject({})
	equals(count,2,'onCreate called for each injector')
	inject.destroy()
	equals(count,1,'onDestroy called once')
	inject2.destroy()
	equals(count,0,'onDestroy called for both')

test 'parent injector', ->
	expect 3
	parent = Inject({
		name: 'foo'
		factory: -> 123
	},{
		name: 'bar'
		factory: -> 'abc'
	})

	child = Inject({
		name: 'baz'
		factory: -> 'baz!'
	},{
		name: 'parent-injector-config'
		injector: parent
	})

	child('foo','bar','baz',(foo,bar,baz) ->
		equals foo, 123
		equals bar, 'abc'
		equals baz, 'baz!'
	)()
