
var CoffeeScript = require('coffee-script');
CoffeeScript.register();

var app = require('./app')(function(){
    console.log("Server listening on port "+ app.get('port'))
});
