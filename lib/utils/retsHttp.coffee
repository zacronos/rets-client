### jshint node:true ###
### jshint -W097 ###
'use strict'

Promise = require('bluebird')
debug = require('debug')('rets-client:main')
expat = require('node-expat')

errors = require('./errors')
headersHelper = require('./headers')


callRetsMethod = (methodName, retsSession, queryOptions) ->
  debug("RETS #{methodName}:", queryOptions)
  Promise.try () ->
    retsSession(qs: queryOptions)
  .catch (error) ->
    debug "RETS #{methodName} error:", error
    Promise.reject(error)
  .spread (response, body) ->
    if response.statusCode != 200
      error = new errors.RetsServerError(methodName, response.statusCode, response.statusMessage, response.rawHeaders)
      debug "RETS #{methodName} error: #{error.message}"
      return Promise.reject(error)
    body: body
    response: response
    headerInfo: headersHelper.processHeaders(response.rawHeaders)


streamRetsMethod = (methodName, retsSession, queryOptions, failCallback, responseCallback, client) ->
  debug("RETS #{methodName} (streaming)", queryOptions)
  done = false
  errorHandler = (error) ->
    if done
      return
    done = true
    debug "RETS #{methodName} (streaming) error:", error
    failCallback(error)
  responseHandler = (response) ->
    if done
      return
    done = true
    if response.statusCode != 200
      error = new errors.RetsServerError(methodName, response.statusCode, response.statusMessage, response.rawHeaders)
      debug "RETS #{methodName} (streaming) error: #{error.message}"
      failCallback(error)
    else if responseCallback
      responseCallback(response)
  request = {}
  if client.settings.method == 'POST'
    request.form = queryOptions
  else
    request.qs = queryOptions
  if methodName == 'getObject'
    request.headers = { Accept: 'text/xml' }
  stream = retsSession(request)
  stream.on 'error', errorHandler
  stream.on 'response', responseHandler


module.exports =
  callRetsMethod: callRetsMethod
  streamRetsMethod: streamRetsMethod
