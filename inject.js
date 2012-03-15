steal.plugins('jquery','jquery/class').then(function($){

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

			if(def.factory) {
				factoryFn = def.factory.injected ? def.factory(resolver) : def.factory;
				factory = function() {
					return results[name] || (results[name] = factoryFn());
				};
			}

			factories[name] = factory;
		});

		function resolver(name) {
			var configs, controller, mapping, def = {};


			// the factories are already built, so we just need to get the inject definitions
			// to create the mapping
			if(name && name.controller) {
				controller = name;
				name = getName(controller);

			}

			// find matching definitions and collapse them into def
			$.each(findAll(defs,function(d) {
				return name && d.name && d.name === name &&
					(!controller || !d.controller || controller.element.is(d.controller));
			}),function() {
				$.extend(true,def,this);
			});

			// def just tells us how to map the dependency names to global names
			mapping = mapper(def);

			return resolve;
			function resolve(name) {
				name = mapping(name);
				return factories[name] && factories[name]();
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
					var target = this,
						deferreds = map(dependencies,resolver(name || nameOf(target)));
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
		$.each(array,function(index) {
			if(fn.call(context,this,index)) {
				result = this;
			}
		});
		return result;
	}

	function findAll(array,fn,context) {
		var result = [];
		fn = fn || function(it) { return it; };
		$.each(array,function(index) {
			if(fn.call(context,this,index)) {
				result.push(this);
			}
		});
		return result;
	}
});