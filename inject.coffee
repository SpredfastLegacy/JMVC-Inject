if steal.plugins
	steal.plugins('jquery')('./inject-core.js','./controller.js').
		then('./cache.js','./eager.js')
else
	steal('jquery','./inject-core.js','./controller.js').then('./cache.js','./eager.js')
