### jshint node:true ###
### jshint -W097 ###
'use strict'

Promise = require('bluebird')
logger = require('winston')
expat = require('node-expat')

errors = require('./errors')


callRetsMethod = (methodName, retsSession, queryOptions) ->
  ###
  Promise.resolve
    body: require('fs').readFileSync("/Users/joe/work/realtymaps/tmp/dump_#{methodName}_#{queryOptions.offset||0}.xml")
    response: {"headers":{"rets-version":"RETS/1.7.2","server":"nginx/1.6.0"}}
  ###
  logger.debug("RETS #{methodName}", queryOptions)
  Promise.try () ->
    retsSession(qs: queryOptions)
  .catch (error) ->
    logger.debug "RETS #{methodName} error:\n" + JSON.stringify(error)
    Promise.reject(error)
  .spread (response, body) ->
    if response.statusCode != 200
      error = new errors.RetsServerError(methodName, response.statusCode, response.statusMessage)
      logger.debug "RETS #{methodName} error:\n" + error.message
      return Promise.reject(error)
    body: body
    response: response


streamRetsMethod = (methodName, retsSession, queryOptions, failCallback) ->
  #require('fs').createReadStream("/Users/joe/work/realtymaps/tmp/dump_#{methodName}_#{queryOptions.offset||0}.xml")
  logger.debug("RETS #{methodName} stream", queryOptions)
  done = false
  errorHandler = (error) ->
    if done
      return
    done = true
    logger.debug "RETS #{methodName} error:\n" + JSON.stringify(error)
    failCallback(error)
  responseHandler = (response) ->
    if done
      return
    done = true
    if response.statusCode != 200
      error = new errors.RetsServerError('search', response.statusCode, response.statusMessage)
      logger.debug "RETS #{methodName} error:\n" + error.message
      failCallback(error)
  stream = retsSession(qs: queryOptions)
  stream.on 'error', errorHandler
  stream.on 'response', responseHandler


module.exports =
  callRetsMethod: callRetsMethod
  streamRetsMethod: streamRetsMethod
