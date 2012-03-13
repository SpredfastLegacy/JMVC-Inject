//steal/js inject/scripts/compress.js

load("steal/rhino/steal.js");
steal.plugins('steal/build','steal/build/scripts','steal/build/styles',function(){
	steal.build('inject/scripts/build.html',{to: 'inject'});
});
