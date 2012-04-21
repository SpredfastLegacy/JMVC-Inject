###
	Requirements:
		jQuery or DoneJS/CanJS ($.when and $.extend)

	Optional:
		JavaScriptMVC/DoneJS/CanJS
			$.String.getObject - required for parameterized factories
###
window = this

exports = window

factoryName = ///
	^			# match the whole string
	([^(]+)		# everything up the ( or the end is the real name
	(\(			# 2nd capture is the ()
		(.*?)?	# 3rd capture is the arguments, unparsed
	\))?
	$
///

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
	getObject: bind(can,'getObject') #optional, but we know it's there
else
	unless window.jQuery or window.$?.when and window.$?.extend
		throw new Error("Either JavaScriptMVC, DoneJS, CanJS or jQuery is required.")
	when: bind(jQuery,'when')
	extend: bind(jQuery,'extend')
	getObject: if jQuery.String?.getObject
		bind(jQuery.String,'getObject')
	else -> throw new Error("Cannot use controllers without JMVC")






# the global stack of injectors
CONTEXT = []

inject = (defs...)->
	factories = {}
	results = {}
	defs = groupBy(defs,'name')
	eager = []

	resolver = (name) ->
		def = {}

		# the factories are already built, so we just need to get the inject definitions
		# to create the mapping
		if(name && name.controller)
			controller = name.controller
			name = getName(controller)

		# find matching definitions and collapse them into def
		###
			Important note: jQuery.is is required to use a controller selector.
		###
		D.extend(true,def,d) for d in defs[name] || [] when \
			!controller || !d.controller || controller.element.is(d.controller)

		# def just tells us how to map the dependency names to global names
		mapping = mapper(def)

		resolve = (name) ->
			# TODO enable for non-controllers? would be accessing globals...
			sub = (name) ->
				controller && substitute(name,controller.options) || name

			get = (path) ->
				unless controller
					throw new Error("parameterized factories can only be used on controllers. Cannot resolve '#{path}' for '#{name}' AKA '#{realName}'")
				D.getObject(path,[controller.options])


			parts = factoryName.exec(mapping(sub(name)))
			realName = parts[1]
			args = (get(path) for path in parts[3]?.split(',') ? [] when path)

			unless factories[realName]
				throw new Error("Cannot resolve '#{realName}' AKA '#{name}'")

			factories[realName].apply(this,args)

	injector = whenInjected(resolver)

	# pre-create factories
	for name, configs of defs
		def = {}

		D.extend(true,def,d) for d in configs

		[name,factory] = makeFactory(def)

		eager.push(factory) if def.eager

		factories[name] = factory

	# run the eager factories (presumably they cache themselves)
	# eager factories are built in to make it easier to resolve dependencies of the eager factory
	useInjector(injector, ->
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
			injected = context.named(name).apply(this,args) # create an injected function
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

inject.useCurrent = (fn) ->
	context = last(CONTEXT);
	unless context
		noContext()
	useInjector(context,fn)

noContext = ->
	throw new Error("""There is no current injector.
	You need to call this inside an injected function or an inject.useCurrent function.""")

# cache offers a simple mechanism for creating (and clearing) singletons
# without caching, the injected values are recreated/resolved each time
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

inject.setupControllerActions = ->
	for funcName, action of getClass(this).actions
		this[funcName] = inject.useCurrent(this[funcName])

	@_super.apply(this,arguments)

makeFactory = (def)->
	[fullName, name, params] = factoryName.exec(def.name)
	fn = def.factory
	[name, ->
		unless fn
			throw new Error("#{fullName} does not have a factory function so it cannot be injected into a function.");
		if arguments.length && !params
			throw new Error("#{fullName} is not a parameterized factory, it cannot take arguments. If you want to pass it arguments, the name must end with '()'.")
		fn.apply(this,arguments)
	]

substitute = (string,options) ->
	string.replace /\{(.+?)\}/g, (param,name) ->
		D.getObject(name,[options])

whenInjected = (resolver) ->
	destroyed = false
	# injectorFor creates requires(), which is what the user sees as the injector
	injectorFor = (name) ->
		requires = (dependencies...,fn)->
			fn = useInjector injector, fn # make sure the function retains the right context
			# when takes a list of the dependencies and the function to inject
			# and returns a function that will resolve the dependencies and pipe them into the function
			injected = useInjector injector, (args...) -> # set the context when the injected function is called
				return if destroyed
				target = this
				resolve = resolver(name || nameOf(target))
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

nameOf = (target) ->
	if target.element && getClass(target)
		controller: target
	else
		getName(target)

getName = (target) ->
	target?.options?.inject?.name || getClass(target)?.fullName

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
