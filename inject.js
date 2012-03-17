steal.plugins('jquery','jquery/class').then(function($){

	var factoryName = /^([^(]+)(\((.*?)?\))?$/;

	var noop = function() {},
		error = window.console && console.error || noop;

	function injector() {
		var factories = {},
			results = {},
			defs = groupBy(flatten(toArray(arguments)),'name');

		// pre-create factories
		$.each(defs,function(name,defs) {
			var def = {}, factory, factoryFn;
			map(defs,function(d) {
				$.extend(true,def,d);
			});

			var parts = factoryName.exec(name),
				isParameterized = !!parts[2],
				args = findAll((parts[3] || '').split(','));
			name = parts[1];

			if(def.factory) {
				factoryFn = def.factory.injected ? def.factory(resolver) : def.factory;
				factory = function() {
					if(!isParameterized && arguments.length) {
						throw new Error(name+' is not a parameterized factory, it cannot take arguments. If you want to pass it arguments, the name must end with "()".');
					}
					return factoryFn.apply(this,arguments);
				};
			}

			factories[name] = factory;

			if(def.eager && factory) {
				factory();
			}
		});

		function resolver(name) {
			var configs, controller, mapping, def = {};


			// the factories are already built, so we just need to get the inject definitions
			// to create the mapping
			if(name && name.controller) {
				controller = name.controller;
				name = getName(controller);

			}

			// find matching definitions and collapse them into def
			$.each(findAll(defs[name] || [],function(d) {
				return (!controller || !d.controller || controller.element.is(d.controller));
			}),function() {
				$.extend(true,def,this);
			});

			// def just tells us how to map the dependency names to global names
			mapping = mapper(def);

			return resolve;
			function resolve(name) {
				var parts = factoryName.exec(mapping(sub(name))),
					realName = parts[1],
					args = map(findAll((parts[3] || '').split(',')),get);

				if(!factories[realName]) {
					throw new Error('Cannot resolve '+realName+' AKA '+name);
				}

				return factories[realName].apply(this,args);

				// TODO enable for non-controllers? would be accessing globals...
				function sub(name) {
					return controller ? substitute(name,controller && controller.options) : name;
				}

				function get(path) {
					if(!controller) {
						throw new Error('parameterized factories can only be used on controllers. Cannot resolve "'+path+' for "'+name+'"" AKA '+realName);
					}
					return $.String.getObject(path,[controller.options]);
				}
			}
		}

		return whenInjected(resolver);
	}

	injector.when = function() {
		// for factory functions, we have to late bind the resolver, so we need to flag
		// the factory function
		var args = toArray(arguments);
		injectedFactory.injected = true;
		return injectedFactory;
		function injectedFactory(resolver) {
			return whenInjected(resolver).apply(this,args);
		}
	};

	injector.cache = cache;

	function cache() {
		var results = {};

		singleton.clear = function() {
			keys = flatten(toArray(arguments));
			if(keys.length) {
				map(keys,function(key) {
					if(key.args) {
						matchArgs(results[key.name],key.args,true)
					} else {
						delete results[key];
					}
				});
			} else {
				results = {};
			}
		};

		return singleton;
		function singleton(name,fn) {
			return function cachedFactory() {
				var args = toArray(arguments),
					array = results[name] || (results[name] = []),
					result = matchArgs(array,args || []);

				if(!result) {
					result = { value: fn.apply(this,args), args: args };
					array.push(result);
				}

				return result.value;
			}
		}
	}

	function substitute(string,options) {
		return string.replace(/\{(.+?)\}/g,function(param,name) {
			return $.String.getObject(name,[options]);
		});
	}

	function whenInjected(resolver) {
		return when;
		function when() {
			var args = toArray(arguments),
				fn = last(args),
				dependencies = initial(args),
				injector = injectedFor();
			injector.named = injectedFor;
			return injector;
			function injectedFor(name) {
				return injected;
				function injected() {
					try {
						var target = this,
							deferreds = map(dependencies,resolver(name || nameOf(target),target,true));
					} catch(e) {
						error('Error resolving for target:',target);
						throw e;
					}
					return $.when.apply($,deferreds).pipe(function() {
						return fn.apply(target,arguments);
					});
				};
			}
		}
	}

	function nameOf(target) {
		return target.element && target.Class ?
			{ controller:target } :
			getName(target);
	}

	function getName(target) {
		return (target && target.options && target.options.inject || {}).name ||
			target && target.Class && target.Class.fullName;
	}

	function mapper(config) {
		config = config || {};
		config.inject = config.inject || {};
		return mapProperty;
		function mapProperty(property) {
			return config.inject[property] || property;
		}
	}

	function matchArgs(results,args,del) {
		if(!results) return;

		var miss, result, idx;
		for(var i = 0; i < results.length; i++) {
			result = results[i];
			miss = find(result.args || [],function(index,arg) {
				idx = index;
				return args[index] !== arg;
			});

			if(!miss) {
				if(del) delete result[i];
				return result;
			}
		}
	}

	window.injector = injector;

	// Support Functions

	function toArray(array) {
		return Array.prototype.slice.call(array,0);
	}

	function flatten(array) {
		var out = [];

		$.each(array,function() {
			if($.isArray(this)) {
				out = out.concat( map(this,flatten) );
			} else {
				out.push(this);
			}
		});

		return out;
	}

	function groupBy(array,fn) {
		var prop = fn;
		if(!fn.call || !fn.apply) {
			fn = function(it) {
				return it && it[prop];
			};
		}
		var obj = {};
		$.each(array,function() {
			var key = fn(this);
			if(obj[key]) {
				obj[key].push(this);
			} else {
				obj[key] = [this];
			}
		});
		return obj;
	}

	function map(array,fn,context) {
		var out = [];
		$.each(array,function(index) {
			out.push(fn.call(context,this,index));
		});
		return out;
	}

	function initial(array) {
		return array && array.slice(0,array.length - 1);
	}
	function last(array) {
		return array && array[array.length - 1];
	}

	function find(array,fn,context) {
		var result;
		fn = fn || function(it) { return it; };
		$.each(array,function(index,value) {
			if(fn.call(context,value,index)) {
				result = value;
			}
		});
		return result;
	}

	function findAll(array,fn,context) {
		var result = [];
		fn = fn || function(it) { return it; };
		$.each(array,function(index,value) {
			if(fn.call(context,value,index)) {
				result.push(value);
			}
		});
		return result;
	}

});