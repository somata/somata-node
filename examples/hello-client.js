var somata = require('somata');

var hello_client = new somata.Client();

hello_client.remote('hello', 'sayHello', 'world', function (err, response) {
    console.log('Got response: ' + response);
});

hello_client.subscribe('hello', 'hi', function (event) {
    console.log('Got event: ' + event);
});