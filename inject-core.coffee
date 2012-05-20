###
	Requirements:
		jQuery or DoneJS/CanJS ($.when and $.extend)

###
window = this

exports = window

error = if window.console and console.error
	(args...) -> console.error.apply(console,args)
else
	->

bind = (obj,name) ->
	fn = obj[name]
	unless fn
		throw new Error("#{name} is not defined.")
	(args...) ->
		fn.apply(obj,args)

# D is for Dependencies
D = if window.can
	when: bind(can,'when')
	extend: bind(can,'extend')
else
	unless window.jQuery or window.$?.when and window.$?.extend
		throw new Error("Either JavaScriptMVC, DoneJS, CanJS or jQuery/Zepto is required.")
	when: bind(window.jQuery or window.$,'when')
	extend: bind(window.jQuery or window.$,'extend')





# the global stack of injectors
CONTEXT = []
PLUGINS = []

inject = (defs...)->
	factories = {}
	results = {}
	defs = groupBy(defs,'name')
	eager = []

	resolver = (obj) ->
		def = definition(obj)
		controller = def.controllerInstance

		# def just tells us how to map the dependency names to global names
		mapping = mapper(def)

		resolve = (name) ->
			realName = mapping(name)
			factory = factories[realName]

			# let the plugins override the factory
			for plugin in PLUGINS when plugin.resolveFactory
				factory = plugin.resolveFactory(obj,realName,def) || factory

			unless factory
				throw new Error("Cannot resolve '#{realName}' AKA '#{name}'")

			factory.call(this)

	definition = (target) ->
		context = last(CONTEXT)
		name = context.name || getName(target)
		def = {}

		definitions = (defs[name] || []).slice(0)

		# let the plugins add additional definitions
		for plugin in PLUGINS when plugin.processDefinition
			definitions.push(plugin.processDefinition(target,definitions) || {})

		# collapse all the definitions
		D.extend(true,def,d) for d in definitions

		def

	injector = whenInjected(resolver,definition)

	# pre-create factories
	for name, configs of defs
		def = {}

		D.extend(true,def,d) for d in configs

		name = def.name
		factory = def.factory

		eager.push(factory) if def.eager

		factories[name] = factory

	# run the eager factories (presumably they cache themselves)
	# eager factories are built in to make it easier to resolve dependencies of the eager factory
	useInjector({injector:injector,definition:definition}, ->
		factory() for factory in eager
	).call(this)

	injector

# support for injecting using the current context
injectUnbound = (name) ->
	require = (args...) ->
		injectCurrent = ->
			context = last(CONTEXT)
			unless context
				noContext()
			injected = context.injector.named(name).apply(this,args) # create an injected function
			injected.apply(this,arguments) # and call it
		injectCurrent.andReturn = andReturn
		injectCurrent

# require with no name
inject.require = injectUnbound()

inject.require.named = injectUnbound


useInjector = (injector,fn) ->
	return ->
		try
			CONTEXT.push(injector)
			fn.apply(this,arguments)
		finally
			CONTEXT.pop()

inject.useCurrent = (fn,ignoreNoContext) ->
	context = last(CONTEXT)
	unless context or ignoreNoContext
		noContext()
	if context then useInjector(context,fn) else fn

noContext = ->
	throw new Error("""There is no current injector.
	You need to call this inside an injected function or an inject.useCurrent function.""")

# cache offers a simple mechanism for creating (and clearing) singletons
# without caching, the injected values are recreated/resolved each time
# TODO plugin
cache = inject.cache = ->
	results = {}

	singleton = (name,fn) ->
		cachedFactory = (args...) ->
			array = results[name] || (results[name] = [])
			result = matchArgs(array,args || [])

			unless result
				result = value: fn.apply(this,args), args: args
				array.push(result);

			result.value;

	singleton.def = (name,fn,eager) ->
		name: name
		eager: eager
		factory: this(name,fn)

	singleton.clear = (keys...)->
		if keys.length
			for key in keys
				if key.args
					matchArgs(results[key.name],key.args,true)
				else
					delete results[key]
		else
			results = {}

	singleton

whenInjected = (resolver,definition) ->
	destroyed = false
	# injectorFor creates requires(), which is what the user sees as the injector
	injectorFor = (name) ->
		requires = (dependencies...,fn)->
			injectContext =
				injector: injector
				name: name
				definition: definition
			fn = useInjector injectContext, fn # make sure the function retains the right context
			# when takes a list of the dependencies and the function to inject
			# and returns a function that will resolve the dependencies and pipe them into the function
			injected = useInjector injectContext, (args...) -> # set the context when the injected function is called
				return if destroyed
				target = this
				resolve = resolver(target)
				try
					deferreds = (resolve(d) for d in dependencies)
				catch e
					error('Error resolving for target:',target)
					throw e
				D.when.apply(D,deferreds.concat(args)).pipe ->
					fn.apply(target,arguments) unless destroyed
			injected.andReturn = andReturn
			injected

	# XXX to support named functions, we have to expose injectorFor, which allows the name to be curried
	injector = injectorFor() # no name resolves by the target object
	injector.named = injectorFor
	injector.destroy = ->
		destroyed = true
	injector

andReturn = (afterAdvice) ->
	fn = this
	unless afterAdvice.apply
		afterAdvice = ((value)-> -> value )(afterAdvice)
	(args...) ->
		def = fn.apply(this,args)
		afterAdvice.apply(this,[def].concat(args))

getName = (target) ->
	getClass(target)?.fullName

getClass = (target) ->
	target?.Class || target?.constructor

mapper = (config) ->
	mapProperty = (property) ->
		config?.inject?[property] || property

matchArgs = (results,args,del) ->
	return unless results

	for result, i in results
		miss = find result.args || [], (index,arg) ->
			args[index] isnt arg

		unless miss
			if del
				delete result[i]
			return result

exports.Inject = inject


## Plugins ##

###
	Plugins can define 3 methods:

	* init(pluginSupport) - passed the plugin support object, which has some helper functions.
	* processDefinition(target,definitions) -
		can return an additional definition object that will override the other definitions.
		DO NOT call pluginSupport.definition inside this method.
	* resolveFactory(target,name,targetDefinition) -
		can return a factory function that will override the defined factory.
###

pluginSupport =
	###
		Helper for getting a copy of the definition used to inject the given object in the current context.

		@param {Object|String} target the thing to be injected, or its name. Some plugins may
		return a different definition for an instance than they would for the name.
		@return {Object} a copy of the injection definition for target in the current injector.
	###
	definition: (target) ->
		context = last(CONTEXT)

		unless context
			noContext()

		# fake an object it for names
		if typeof target == 'string'
			target =
				Class:
					fullName: target

		context.definition(target)

inject.plugin = (plugin)->
	PLUGINS.push(plugin)
	if plugin.init
		plugin.init(pluginSupport)

## Support Functions ##

groupBy = (array,fn) ->
	prop = fn;
	unless fn.call and fn.apply
		fn = (it) -> it?[prop]

	obj = {}
	for e in array
		key = fn(e)
		if obj[key]
			obj[key].push(e)
		else
			obj[key] = [e]
	obj

last = (array) ->
	array?[array?.length - 1]

find = (array,fn,context) ->
	fn ?= (it) -> it
	for value, index in array
		return value if fn.call(context,value,index)
