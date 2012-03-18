(function() {
  var __slice = Array.prototype.slice;

  steal.plugins('jquery', 'jquery/class').then(function($) {
    var CONTEXT, cache, error, exports, factoryName, find, getName, groupBy, inject, last, makeFactory, mapper, matchArgs, nameOf, substitute, useInjector, whenInjected;
    exports = window;
    factoryName = /^([^(]+)(\((.*?)?\))?$/;
    error = window.console && console.error || function() {};
    CONTEXT = [];
    inject = function() {
      var configs, d, def, defs, eager, factories, factory, injector, name, resolver, results, _i, _len, _ref;
      defs = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      factories = {};
      results = {};
      defs = groupBy(defs, 'name');
      eager = [];
      resolver = function(name) {
        var controller, d, def, mapping, resolve, _i, _len, _ref;
        def = {};
        if (name && name.controller) {
          controller = name.controller;
          name = getName(controller);
        }
        _ref = defs[name] || [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          d = _ref[_i];
          if (!controller || !d.controller || controller.element.is(d.controller)) {
            $.extend(true, def, d);
          }
        }
        mapping = mapper(def);
        return resolve = function(name) {
          var args, get, parts, path, realName, sub;
          sub = function(name) {
            return controller && substitute(name, controller.options) || name;
          };
          get = function(path) {
            if (!controller) {
              throw new Error("parameterized factories can only be used on controllers. Cannot resolve '" + path + "' for '" + name + "' AKA '" + realName + "'");
            }
            return $.String.getObject(path, [controller.options]);
          };
          parts = factoryName.exec(mapping(sub(name)));
          realName = parts[1];
          args = (function() {
            var _j, _len2, _ref2, _ref3, _ref4, _results;
            _ref4 = (_ref2 = (_ref3 = parts[3]) != null ? _ref3.split(',') : void 0) != null ? _ref2 : [];
            _results = [];
            for (_j = 0, _len2 = _ref4.length; _j < _len2; _j++) {
              path = _ref4[_j];
              if (path) _results.push(get(path));
            }
            return _results;
          })();
          if (!factories[realName]) {
            throw new Error("Cannot resolve '" + realName + "' AKA '" + name + "'");
          }
          return factories[realName].apply(this, args);
        };
      };
      injector = whenInjected(resolver);
      for (name in defs) {
        configs = defs[name];
        def = {};
        for (_i = 0, _len = configs.length; _i < _len; _i++) {
          d = configs[_i];
          $.extend(true, def, d);
        }
        _ref = makeFactory(def), name = _ref[0], factory = _ref[1];
        if (def.eager) eager.push(factory);
        factories[name] = factory;
      }
      useInjector(injector, function() {
        var factory, _j, _len2, _results;
        _results = [];
        for (_j = 0, _len2 = eager.length; _j < _len2; _j++) {
          factory = eager[_j];
          _results.push(factory());
        }
        return _results;
      }).call(this);
      return injector;
    };
    inject.require = function() {
      var args, injectCurrent;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return injectCurrent = function() {
        var context, injected;
        context = last(CONTEXT);
        if (!context) {
          throw new Error("There is no current injector.\nYou need to call an injected function or an inject.useInjector/useCurrent function.");
        }
        injected = context.apply(this, args);
        return injected.apply(this, arguments);
      };
    };
    inject.useInjector = useInjector = function(injector, fn) {
      return function() {
        try {
          CONTEXT.push(injector);
          return fn.apply(this, arguments);
        } finally {
          CONTEXT.pop();
        }
      };
    };
    inject.useCurrent = function(fn) {
      var context;
      context = last(CONTEXT);
      if (!context) {
        throw new Error("There is no current injector. You need to call an inject.useInjector function.");
      }
      return inject.useInjector(context, fn);
    };
    cache = inject.cache = function() {
      var results, singleton;
      results = {};
      singleton = function(name, fn) {
        var cachedFactory;
        return cachedFactory = function() {
          var args, array, result;
          args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          array = results[name] || (results[name] = []);
          result = matchArgs(array, args || []);
          if (!result) {
            result = {
              value: fn.apply(this, args),
              args: args
            };
            array.push(result);
          }
          return result.value;
        };
      };
      singleton.clear = function() {
        var key, keys, _i, _len, _results;
        keys = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        if (keys.length) {
          _results = [];
          for (_i = 0, _len = keys.length; _i < _len; _i++) {
            key = keys[_i];
            if (key.args) {
              _results.push(matchArgs(results[key.name], key.args, true));
            } else {
              _results.push(delete results[key]);
            }
          }
          return _results;
        } else {
          return results = {};
        }
      };
      return singleton;
    };
    makeFactory = function(def) {
      var fn, fullName, name, params, _ref;
      _ref = factoryName.exec(def.name), fullName = _ref[0], name = _ref[1], params = _ref[2];
      fn = def.factory;
      return [
        name, function() {
          if (!fn) {
            throw new Error("" + fullName + " does not have a factory function so it cannot be injected into a function.");
          }
          if (arguments.length && !params) {
            throw new Error("" + fullName + " is not a parameterized factory, it cannot take arguments. If you want to pass it arguments, the name must end with '()'.");
          }
          return fn.apply(this, arguments);
        }
      ];
    };
    substitute = function(string, options) {
      return string.replace(/\{(.+?)\}/g, function(param, name) {
        return $.String.getObject(name, [options]);
      });
    };
    whenInjected = function(resolver) {
      var injector, injectorFor;
      injectorFor = function(name) {
        var requires;
        return requires = function() {
          var dependencies, fn, _i;
          dependencies = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), fn = arguments[_i++];
          return useInjector(injector, function() {
            var args, d, deferreds, resolve, target;
            args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
            target = this;
            resolve = resolver(name || nameOf(target));
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
            return $.when.apply($, deferreds.concat(args)).pipe(function() {
              return fn.apply(target, arguments);
            });
          });
        };
      };
      injector = injectorFor();
      injector.named = injectorFor;
      return injector;
    };
    nameOf = function(target) {
      if (target.element && target.Class) {
        return {
          controller: target
        };
      } else {
        return getName(target);
      }
    };
    getName = function(target) {
      var _ref, _ref2, _ref3;
      return (target != null ? (_ref = target.options) != null ? (_ref2 = _ref.inject) != null ? _ref2.name : void 0 : void 0 : void 0) || (target != null ? (_ref3 = target.Class) != null ? _ref3.fullName : void 0 : void 0);
    };
    mapper = function(config) {
      var mapProperty;
      return mapProperty = function(property) {
        var _ref;
        return (config != null ? (_ref = config.inject) != null ? _ref[property] : void 0 : void 0) || property;
      };
    };
    matchArgs = function(results, args, del) {
      var i, miss, result, _len;
      if (!results) return;
      for (i = 0, _len = results.length; i < _len; i++) {
        result = results[i];
        miss = find(result.args || [], function(index, arg) {
          return args[index] !== arg;
        });
        if (!miss) {
          if (del) delete result[i];
          return result;
        }
      }
    };
    exports.inject = inject;
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
    return find = function(array, fn, context) {
      var index, value, _len;
      if (fn == null) {
        fn = function(it) {
          return it;
        };
      }
      for (index = 0, _len = array.length; index < _len; index++) {
        value = array[index];
        if (fn.call(context, value, index)) return value;
      }
    };
  });

}).call(this);
