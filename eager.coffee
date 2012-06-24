pluginSupport = null

onCreate = (names,id) ->
	# run the eager factories (presumably they cache themselves)
	for name in names
		config = pluginSupport.definition(name)
		config.factory() if config.eager

Inject.plugin
	init: (support) ->
		pluginSupport = support
	onCreate: onCreate
