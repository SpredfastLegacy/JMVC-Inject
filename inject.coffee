if steal.plugins
	steal.plugins('jquery')('//inject/inject-core.js')('//inject/controller.js')
else
	steal('jquery','jquery/lang','./inject-core.js','./controller.js')
