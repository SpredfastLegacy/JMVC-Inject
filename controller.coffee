support = null

factoryName = ///
	^			# match the whole string
	([^(]+)		# everything up the ( or the end is the real name
	(\(			# 2nd capture is the ()
		(.*?)?	# 3rd capture is the arguments, unparsed
	\))?
	$
///



getOptions = (Class,support,args) ->
	el = args[0]
	def = support.definition(Class.fullName)
	# XXX not a typo, we want the last def that matches selector
	def = d for d in def?.controllerDefs || [] when not d.controller or el.is(d.controller)
	def?.options

processDef = (target,defs) ->
	# only process controllers
	return unless target?.element and target?.Class

	# group and collapse
	# XXX must do them in the same order they are defined
	grouped = []
	byKey = {}
	for d in defs
		key = d.controller || ''
		merged = byKey[key]

		if not merged
			merged = byKey[key] = {}
			grouped.push(merged)

		$.extend(true,merged,d)

	# find the last def that matches the controller's element, or is the default
	def = d for d in grouped when not d.controller or target.element.is(d.controller)

	# XXX! return a copy so we don't create a loop in the object graph
	def = $.extend(true,{},def);

	# save the other definitions (for getOptions)
	def.controllerDefs = grouped if def
	def

resolveFactory = (target,name,targetDef) ->
	# only process controllers
	return unless target?.element and target?.Class

	# make options substitutions and resolve parameterize factory arguments
	get = (path) ->
		$.String.getObject(path,[target.options])

	parts = factoryName.exec(substitute(name,target.options) || name)
	realName = parts[1]
	args = (get(path) for path in parts[3]?.split(',') ? [] when path)

	fn = support.definition(realName)?.factory
	-> fn.apply(this,args) if fn

substitute = (string,options) ->
	string.replace /\{(.+?)\}/g, (param,name) ->
		$.String.getObject(name,[options])

(if steal.plugins
	steal('inject-core.js','attrs.js').plugins('jquery/lang')
else
	steal('./inject-core.js','./attrs.js','jquery/lang/string')).then ->

	$ = this.$ || this.can

	exports = Inject

	###
		Important note: jQuery.is is required to use a controller selector.
	###
	Inject.plugin
		processDefinition: processDef
		resolveFactory: resolveFactory
		init: (s) ->
			support = s

	exports.setupController = ->
		Inject.setup.arg(1,getOptions).apply(this,arguments)
		setup = this.prototype.setup
		this.prototype.setup = ->
			for funcName, action of this.Class.actions
				this[funcName] = Inject.useCurrent(this[funcName])
			setup.apply(this,arguments)
