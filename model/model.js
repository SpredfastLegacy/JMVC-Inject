// Generated by CoffeeScript 1.3.3
(function() {

  steal('jquery', 'inject/inject-core.js', 'can/model', function($, Inject, Model) {
    "use strict";

    var pipeInject;
    pipeInject = function(promise) {
      var result;
      result = $.Deferred();
      promise.then(Inject.useCurrent(function() {
        return result.resolve.apply(result, arguments);
      }, true), Inject.useCurrent(function() {
        return result.reject.apply(result, arguments);
      }, true));
      if (promise.abort) {
        result.abort = promise.abort;
      }
      return result.promise();
    };
    return function(fn) {
      return function() {
        return pipeInject(fn.apply(this, arguments));
      };
    };
  });

}).call(this);
