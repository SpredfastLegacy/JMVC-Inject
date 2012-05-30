if steal.plugins
	steal.plugins('jquery')('//inject/inject-core.js')('//inject/controller.js').
		then('//inject/cache.js')
else
	steal('jquery','./inject-core.js','./controller.js').then('./cache.js')
