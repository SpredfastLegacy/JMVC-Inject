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
	when: bind(window.jQuery or window.$ or window.can,'when')
	extend: bind(window.jQuery or window.$ or window.can,'extend')





# the global stack of injectors
CONTEXT = []
PLUGINS = []

IDS = 0

identify = (defs) ->
	name = def.injectorName for def in defs['injector-config'] or []
	name or ("UnnamedInjector("+(name for name, config of defs).join(', ')+")")

inject = (defs...)->
	defs = groupBy(defs,'name')
	eager = []

	resolver = (obj) ->
		def = definition(obj)
		controller = def.controllerInstance

		# def just tells us how to map the dependency names to global names
		mapping = mapper(def)

		resolve = (name) ->
			realName = mapping(name)
			factory = def.factory for def in (defs[realName] || []) when def.factory

			# let the plugins override the factory
			for plugin in PLUGINS when plugin.resolveFactory
				factory = plugin.resolveFactory(obj,realName,def) || factory

			unless factory
				for plugin in PLUGINS when plugin.factoryMissing
					factory = plugin.factoryMissing(obj,realName,def) || factory
				unless factory
					throw new Error("Cannot resolve '#{realName}' AKA '#{name}' in "+identify(defs))

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

	injector = whenInjected resolver,
		definition: definition
		id: id = ++IDS
		add:  (name,newDef)->
			defs[name] = defs[name] || []
			defs[name].push(newDef)

	# run plugins
	injector( ->
		definitions = {}
		for plugin in PLUGINS when plugin.onCreate
			plugin.onCreate((name for name, config of defs),id)
	).call(this)

	injector

# support for injecting using the current context
injectUnbound = (name) ->
	require = (args...) ->
		injectCurrent = ->
			context = last(CONTEXT)
			unless context
				noContext(args)
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

inject.useCurrent = (args...,fn,ignoreNoContext) ->
	if ignoreNoContext?.apply
		args = args.concat(fn)
		fn = ignoreNoContext
		ignoreNoContext = false
	if args.length
		fn = Inject.require.apply(Inject,args.concat([fn]))
	context = last(CONTEXT)
	unless context or ignoreNoContext
		noContext(args)
	if context then useInjector(context,fn) else fn

noContext = (args)->
	if args
		throw new Error("There is no current injector for: "+args.join(', '))
	else
		throw new Error("""There is no current injector.
You need to call this inside an injected function or an inject.useCurrent function.""")


whenInjected = (resolver,ctx) ->
	destroyed = false
	# injectorFor creates requires(), which is what the user sees as the injector
	injectorFor = (name) ->
		requires = (dependencies...,fn)->
			injectContext = D.extend(true,
				injector: injector
				name: name
			,ctx)
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
		plugin.onDestroy(ctx.id) for plugin in PLUGINS when plugin.onDestroy
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

exports.Inject = inject


## Plugins ##

pluginSupport =
	###
		Allows the plugin to add an additional permanent definition to the current
		injector.

		@param {Object} def the new definition to add
	###
	addDefinition: (def) ->
		context = last(CONTEXT)

		unless context
			noContext()

		context.add(def.name,def)

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

	###
		@return the unique id of the current injector
	###
	injectorId: ->
		context = last(CONTEXT)

		unless context
			noContext()

		context.id

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

if this.steal
	steal () -> inject
