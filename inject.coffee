if steal.plugins
	steal.plugins('jquery')('./inject-core.js','./controller.js').
		then('./cache.js','./eager.js').then('./parent.js')
else
	steal('jquery').then('./inject-core.js','./controller.js').then('./cache.js','./eager.js').
		then('./parent.js').then () -> Inject
