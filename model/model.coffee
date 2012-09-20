steal 'jquery','inject/inject-core.js','can/model', ($,Inject,Model) ->
	"use strict"

	pipeInject = (promise) ->
		result = $.Deferred();
		promise.then Inject.useCurrent( ->
			result.resolve.apply(result,arguments)
		,true),Inject.useCurrent( ->
			result.reject.apply(result,arguments)
		,true)
		if promise.abort
			result.abort = promise.abort

		result.promise()

	(fn) ->
		->
			pipeInject fn.apply(this, arguments )
