// Generated by CoffeeScript 1.3.3

/*
	Requirements:
		jQuery or DoneJS/CanJS ($.when and $.extend)
*/


(function() {
  var CONTEXT, D, IDS, PLUGINS, andReturn, bind, error, exports, getClass, getName, groupBy, identify, inject, injectUnbound, last, mapper, noContext, pluginSupport, useInjector, whenInjected, window,
    __slice = [].slice;

  window = this;

  exports = window;

  error = window.console && console.error ? function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return console.error.apply(console, args);
  } : function() {};

  bind = function(obj, name) {
    var fn;
    fn = obj[name];
    if (!fn) {
      throw new Error("" + name + " is not defined.");
    }
    return function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return fn.apply(obj, args);
    };
  };

  D = (function() {
    var _ref, _ref1;
    if (window.can) {
      return {
        when: bind(can, 'when'),
        extend: bind(can, 'extend')
      };
    } else {
      if (!(window.jQuery || ((_ref = window.$) != null ? _ref.when : void 0) && ((_ref1 = window.$) != null ? _ref1.extend : void 0))) {
        throw new Error("Either JavaScriptMVC, DoneJS, CanJS or jQuery/Zepto is required.");
      }
      return {
        when: bind(window.jQuery || window.$ || window.can, 'when'),
        extend: bind(window.jQuery || window.$ || window.can, 'extend')
      };
    }
  })();

  CONTEXT = [];

  PLUGINS = [];

  IDS = 0;

  identify = function(defs) {
    var config, def, name, _i, _len, _ref;
    _ref = defs['injector-config'] || [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      def = _ref[_i];
      name = def.injectorName;
    }
    return name || ("UnnamedInjector(" + ((function() {
      var _results;
      _results = [];
      for (name in defs) {
        config = defs[name];
        _results.push(name);
      }
      return _results;
    })()).join(', ') + ")");
  };

  inject = function() {
    var definition, defs, eager, id, injector, resolver;
    defs = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    defs = groupBy(defs, 'name');
    eager = [];
    resolver = function(obj) {
      var controller, def, mapping, resolve;
      def = definition(obj);
      controller = def.controllerInstance;
      mapping = mapper(def);
      return resolve = function(name) {
        var factory, plugin, realName, _i, _j, _k, _len, _len1, _len2, _ref;
        realName = mapping(name);
        _ref = defs[realName] || [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          def = _ref[_i];
          if (def.factory) {
            factory = def.factory;
          }
        }
        for (_j = 0, _len1 = PLUGINS.length; _j < _len1; _j++) {
          plugin = PLUGINS[_j];
          if (plugin.resolveFactory) {
            factory = plugin.resolveFactory(obj, realName, def) || factory;
          }
        }
        if (!factory) {
          for (_k = 0, _len2 = PLUGINS.length; _k < _len2; _k++) {
            plugin = PLUGINS[_k];
            if (plugin.factoryMissing) {
              factory = plugin.factoryMissing(obj, realName, def) || factory;
            }
          }
          if (!factory) {
            throw new Error(("Cannot resolve '" + realName + "' AKA '" + name + "' in ") + identify(defs));
          }
        }
        return factory.call(this);
      };
    };
    definition = function(target) {
      var context, d, def, definitions, name, plugin, _i, _j, _len, _len1;
      context = last(CONTEXT);
      name = context.name || getName(target);
      def = {};
      definitions = (defs[name] || []).slice(0);
      for (_i = 0, _len = PLUGINS.length; _i < _len; _i++) {
        plugin = PLUGINS[_i];
        if (plugin.processDefinition) {
          definitions.push(plugin.processDefinition(target, definitions) || {});
        }
      }
      for (_j = 0, _len1 = definitions.length; _j < _len1; _j++) {
        d = definitions[_j];
        D.extend(true, def, d);
      }
      return def;
    };
    injector = whenInjected(resolver, {
      definition: definition,
      id: id = ++IDS,
      add: function(name, newDef) {
        defs[name] = defs[name] || [];
        return defs[name].push(newDef);
      }
    });
    injector(function() {
      var config, definitions, name, plugin, _i, _len, _results;
      definitions = {};
      _results = [];
      for (_i = 0, _len = PLUGINS.length; _i < _len; _i++) {
        plugin = PLUGINS[_i];
        if (plugin.onCreate) {
          _results.push(plugin.onCreate((function() {
            var _results1;
            _results1 = [];
            for (name in defs) {
              config = defs[name];
              _results1.push(name);
            }
            return _results1;
          })(), id));
        }
      }
      return _results;
    }).call(this);
    return injector;
  };

  injectUnbound = function(name) {
    var require;
    return require = function() {
      var args, injectCurrent;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      injectCurrent = function() {
        var context, injected;
        context = last(CONTEXT);
        if (!context) {
          noContext(args);
        }
        injected = context.injector.named(name).apply(this, args);
        return injected.apply(this, arguments);
      };
      injectCurrent.andReturn = andReturn;
      return injectCurrent;
    };
  };

  inject.require = injectUnbound();

  inject.require.named = injectUnbound;

  useInjector = function(injector, fn) {
    return function() {
      try {
        CONTEXT.push(injector);
        return fn.apply(this, arguments);
      } finally {
        CONTEXT.pop();
      }
    };
  };

  inject.useCurrent = function() {
    var args, context, fn, ignoreNoContext, _i;
    args = 3 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 2) : (_i = 0, []), fn = arguments[_i++], ignoreNoContext = arguments[_i++];
    if (ignoreNoContext != null ? ignoreNoContext.apply : void 0) {
      args = args.concat(fn);
      fn = ignoreNoContext;
      ignoreNoContext = false;
    }
    if (args.length) {
      fn = Inject.require.apply(Inject, args.concat([fn]));
    }
    context = last(CONTEXT);
    if (!(context || ignoreNoContext)) {
      noContext(args);
    }
    if (context) {
      return useInjector(context, fn);
    } else {
      return fn;
    }
  };

  noContext = function(args) {
    if (args) {
      throw new Error("There is no current injector for: " + args.join(', '));
    } else {
      throw new Error("There is no current injector.\nYou need to call this inside an injected function or an inject.useCurrent function.");
    }
  };

  whenInjected = function(resolver, ctx) {
    var destroyed, injector, injectorFor;
    destroyed = false;
    injectorFor = function(name) {
      var requires;
      return requires = function() {
        var dependencies, fn, injectContext, injected, _i;
        dependencies = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), fn = arguments[_i++];
        injectContext = D.extend(true, {
          injector: injector,
          name: name
        }, ctx);
        fn = useInjector(injectContext, fn);
        injected = useInjector(injectContext, function() {
          var args, d, deferreds, resolve, target;
          args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          if (destroyed) {
            return;
          }
          target = this;
          resolve = resolver(target);
          try {
            deferreds = (function() {
              var _j, _len, _results;
              _results = [];
              for (_j = 0, _len = dependencies.length; _j < _len; _j++) {
                d = dependencies[_j];
                _results.push(resolve(d));
              }
              return _results;
            })();
          } catch (e) {
            error('Error resolving for target:', target);
            throw e;
          }
          return D.when.apply(D, deferreds.concat(args)).pipe(function() {
            if (!destroyed) {
              return fn.apply(target, arguments);
            }
          });
        });
        injected.andReturn = andReturn;
        return injected;
      };
    };
    injector = injectorFor();
    injector.named = injectorFor;
    injector.destroy = function() {
      var plugin, _i, _len;
      for (_i = 0, _len = PLUGINS.length; _i < _len; _i++) {
        plugin = PLUGINS[_i];
        if (plugin.onDestroy) {
          plugin.onDestroy(ctx.id);
        }
      }
      return destroyed = true;
    };
    return injector;
  };

  andReturn = function(afterAdvice) {
    var fn;
    fn = this;
    if (!afterAdvice.apply) {
      afterAdvice = (function(value) {
        return function() {
          return value;
        };
      })(afterAdvice);
    }
    return function() {
      var args, def;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      def = fn.apply(this, args);
      return afterAdvice.apply(this, [def].concat(args));
    };
  };

  getName = function(target) {
    var _ref;
    return (_ref = getClass(target)) != null ? _ref.fullName : void 0;
  };

  getClass = function(target) {
    return (target != null ? target.Class : void 0) || (target != null ? target.constructor : void 0);
  };

  mapper = function(config) {
    var mapProperty;
    return mapProperty = function(property) {
      var _ref;
      return (config != null ? (_ref = config.inject) != null ? _ref[property] : void 0 : void 0) || property;
    };
  };

  exports.Inject = inject;

  pluginSupport = {
    /*
    		Allows the plugin to add an additional permanent definition to the current
    		injector.
    
    		@param {Object} def the new definition to add
    */

    addDefinition: function(def) {
      var context;
      context = last(CONTEXT);
      if (!context) {
        noContext();
      }
      return context.add(def.name, def);
    },
    /*
    		Helper for getting a copy of the definition used to inject the given object in the current context.
    
    		@param {Object|String} target the thing to be injected, or its name. Some plugins may
    		return a different definition for an instance than they would for the name.
    		@return {Object} a copy of the injection definition for target in the current injector.
    */

    definition: function(target) {
      var context;
      context = last(CONTEXT);
      if (!context) {
        noContext();
      }
      if (typeof target === 'string') {
        target = {
          Class: {
            fullName: target
          }
        };
      }
      return context.definition(target);
    },
    /*
    		@return the unique id of the current injector
    */

    injectorId: function() {
      var context;
      context = last(CONTEXT);
      if (!context) {
        noContext();
      }
      return context.id;
    }
  };

  inject.plugin = function(plugin) {
    PLUGINS.push(plugin);
    if (plugin.init) {
      return plugin.init(pluginSupport);
    }
  };

  groupBy = function(array, fn) {
    var e, key, obj, prop, _i, _len;
    prop = fn;
    if (!(fn.call && fn.apply)) {
      fn = function(it) {
        return it != null ? it[prop] : void 0;
      };
    }
    obj = {};
    for (_i = 0, _len = array.length; _i < _len; _i++) {
      e = array[_i];
      key = fn(e);
      if (obj[key]) {
        obj[key].push(e);
      } else {
        obj[key] = [e];
      }
    }
    return obj;
  };

  last = function(array) {
    return array != null ? array[(array != null ? array.length : void 0) - 1] : void 0;
  };

  if (this.steal) {
    steal(function() {
      return inject;
    });
  }

}).call(this);
