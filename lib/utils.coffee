### jshint node:true ###
### jshint -W097 ###
'use strict'

urlUtil = require('url')
Promise = require('bluebird')
logger = require('winston')
expat = require('node-expat')

replycodes = require('./replycodes')


class RetsReplyError extends Error
  constructor: (@replyCode, @replyText) ->
    @name = 'RetsReplyError'
    @replyTag = if replycodes.tagMap[@replyCode]? then replycodes.tagMap[@replyCode] else 'unknown reply code'
    @message = "RETS Server replied with an error code - ReplyCode #{@replyCode} (#{@replyTag}); ReplyText: #{@replyText}"
    Error.captureStackTrace(this, RetsReplyError)


class RetsServerError extends Error
  constructor: (@retsMethod, @httpStatus, @httpStatusMessage) ->
    @name = 'RetsServerError'
    @message = "Error while attempting #{@retsMethod} - HTTP Status #{@httpStatus} returned (#{@httpStatusMessage})"
    Error.captureStackTrace(this, RetsServerError)


# Parsing as performed here and in the other modules of this project relies on some simplifying assumptions.  DO NOT
# COPY OR MODIFY THIS LOGIC BLINDLY!  It works correctly for well-formed XML which adheres to the RETS specifications,
# and does not attempt to check for or properly handle XML not of that form.  In particular, it does not keep track of
# the element stack to ensure elements (and text) are found only in the expected locations.
getBaseObjectParser = (errCallback) ->
  result =
    currElementName: null
    parser: new expat.Parser('UTF-8')
    finish: () ->
      result.parser.stop()
      result.parser.removeAllListeners()
    status: null

  result.parser.once 'startElement', (name, attrs) ->
    if name != 'RETS'
      result.finish()
      return errCallback(new Error('Unexpected results. Please check the RETS URL.'))
  
  result.parser.on 'startElement', (name, attrs) ->
    result.currElementName = name
    if name != 'RETS' && name != 'RETS-STATUS'
      return
    result.status = attrs
    if attrs.ReplyCode != '0' && attrs.ReplyCode != '20208'
      result.finish()
      return errCallback(new RetsReplyError(attrs.ReplyCode, attrs.ReplyText))

  result.parser.on 'error', (err) ->
    result.finish()
    errCallback(new Error("XML parsing error: #{err}"))
  
  return result

      
hex2a = (hexx) ->
  if !hexx?
    return null
  hex = hexx.toString()
  # force conversion
  str = ''
  i = 0
  while i < hex.length
    str += String.fromCharCode(parseInt(hex.substr(i, 2), 16))
    i += 2
  str


# Returns a valid url for use with RETS server. If target url just contains a path, fullURL's protocol and host will be utilized.
getValidUrl = (targetUrl, fullUrl) ->
  loginUrlObj = urlUtil.parse(fullUrl, true, true)
  targetUrlObj = urlUtil.parse(targetUrl, true, true)
  if targetUrlObj.host == loginUrlObj.host
    return targetUrl
  fixedUrlObj =
    protocol: loginUrlObj.protocol
    slashes: true
    host: loginUrlObj.host
    pathname: targetUrlObj.pathname
    query: targetUrlObj.query
  urlUtil.format fixedUrlObj


callRetsMethod = (methodName, retsSession, queryOptions) ->
  Promise.try () ->
    retsSession(qs: queryOptions)
  .catch (error) ->
    logger.debug "RETS #{methodName} error:\n" + JSON.stringify(error)
    Promise.reject(error)
  .spread (response, body) ->
    if response.statusCode != 200
      error = new RetsServerError(methodName, response.statusCode, response.statusMessage)
      logger.debug "RETS #{methodName} error:\n" + error.message
      return Promise.reject(error)
    response: response
    body: body


module.exports =
  RetsReplyError: RetsReplyError
  RetsServerError: RetsServerError
  getBaseObjectParser: getBaseObjectParser
  hex2a: hex2a
  getValidUrl: getValidUrl
  callRetsMethod: callRetsMethod
