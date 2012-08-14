# cache offers a simple mechanism for creating (and clearing) singletons
# without caching, the injected values are recreated/resolved each time
Inject.cache = ->
	results = {}

	singleton = (name,fn) ->
		cachedFactory = (args...) ->
			array = results[name] || (results[name] = [])
			result = matchArgs(array,args || [])

			unless result
				# XXX always create a deferred for the result to
				# avoid infinite recursion from reentering the cache
				# looking for the value
				def = $.Deferred()
				result = value: def.promise(), args: args
				array.push(result)
				$.when(fn.apply(this,args)).then (r) ->
					def.resolve(r)

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

matchArgs = (results,args,del) ->
	return unless results

	for result, i in results
		miss = find result.args || [], (index,arg) ->
			args[index] isnt arg

		unless miss
			if del
				delete result[i]
			return result

find = (array,fn,context) ->
	fn ?= (it) -> it
	for value, index in array
		return value if fn.call(context,value,index)


caches = {}
pluginSupport = null

# support singleton: true
Inject.plugin
	init: (support) ->
		pluginSupport = support

	onCreate: (names,id) ->
		cache = caches[id] = Inject.cache()

		for name in names
			config = pluginSupport.definition(name)
			if config.singleton
				pluginSupport.addDefinition
					name: name
					factory: cache(name,config.factory)

	onDestroy: (id) ->
		delete caches[id]
