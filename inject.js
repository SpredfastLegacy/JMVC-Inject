(function() {

  if (steal.plugins) {
    steal.plugins('jquery', 'jquery/lang')('inject-core.js');
  } else {
    steal('jquery', 'jquery/lang', './inject-core.js');
  }

}).call(this);
