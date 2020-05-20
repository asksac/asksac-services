'use strict'

exports.handler = async function(event, context, callback) {
  var response = {
    statusCode: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8'
    },
    body: '<html><body><h1>Hello World!</h1></body></html>'
  }
  callback(null, response)
}