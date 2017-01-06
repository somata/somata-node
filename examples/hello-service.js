var somata = require('somata');

var hello_service = new somata.Service('hello', {
    sayHello: function (name, cb) {
        cb(null, 'Hello, ' + name + '!');
    }
});

setInterval(function() {
    hello_service.publish('hi', "Just saying hi.");
}, 2000);
