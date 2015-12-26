### jshint node:true ###
### jshint -W097 ###
'use strict'

Promise = require('bluebird')
debug = require('debug')('rets-client:main')
expat = require('node-expat')

errors = require('./errors')


callRetsMethod = (methodName, retsSession, queryOptions) ->
  debug("RETS #{methodName}:", queryOptions)
  Promise.try () ->
    retsSession(qs: queryOptions)
  .catch (error) ->
    debug "RETS #{methodName} error:", error
    Promise.reject(error)
  .spread (response, body) ->
    if response.statusCode != 200
      error = new errors.RetsServerError(methodName, response.statusCode, response.statusMessage)
      debug "RETS #{methodName} error: #{error.message}"
      return Promise.reject(error)
    body: body
    response: response


streamRetsMethod = (methodName, retsSession, queryOptions, failCallback) ->
  debug("RETS #{methodName} (streaming)", queryOptions)
  done = false
  errorHandler = (error) ->
    if done
      return
    done = true
    debug "RETS #{methodName} error:", error
    failCallback(error)
  responseHandler = (response) ->
    if done
      return
    done = true
    if response.statusCode != 200
      error = new errors.RetsServerError('search', response.statusCode, response.statusMessage)
      debug "RETS #{methodName} error: #{error.message}"
      failCallback(error)
  stream = retsSession(qs: queryOptions)
  stream.on 'error', errorHandler
  stream.on 'response', responseHandler


module.exports =
  callRetsMethod: callRetsMethod
  streamRetsMethod: streamRetsMethod
