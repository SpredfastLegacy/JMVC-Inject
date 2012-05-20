setup = (support)->
	exports = Inject

	injectConstructor = (_super,index,getConfig) ->
		(args...) ->
			# get the definition and find the map of attr -> dependency
			config = getConfig(this,support,args)
			target = args[index]

			keys = (key for key, dep of config)
			deps = (dep for key, dep of config)

			# resolve the dependencies and set each one on the target object iff it is undefined
			# then continue construction
			Inject.require.apply(this,deps.concat( (values...) ->
				for value, i in values
					key = keys[i]
					target[key] = value unless has.call(target,key)
				_super.apply(this,args)
			)).call(this)

	exports.setup = ->
		Inject.setup.arg().apply(this,arguments)

	exports.setup.arg = (index = 0,getConfig = getAttrs) ->
		->
			@newInstance = injectConstructor @newInstance, index, getConfig

getAttrs = (Class,support) ->
	support.definition(Class.fullName).attrs ? {}


has = Object.prototype.hasOwnProperty

(if steal.plugins
	steal('inject-core.js')
else
	steal('./inject-core.js')).then ->

	Inject.plugin
		init: setup


