'use strict'

exports.handler = async function(event, context, callback) {
  var response = {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json; charset=utf-8'
    },
    body: JSON.stringify({event: event, context: context})
  }
  callback(null, response)
}