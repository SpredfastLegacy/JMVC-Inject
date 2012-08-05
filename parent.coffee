pluginSupport = null

resolveWithParent = (target,name,def) ->
	def = pluginSupport.definition('parent-injector-config')
	return unless def and def.injector

	# create an injected function using the parent that returns the dependency
	def.injector name, (it) -> it

Inject.plugin
	init: (support) ->
		pluginSupport = support
	factoryMissing: resolveWithParent
