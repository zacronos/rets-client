### jshint node:true ###
### jshint -W097 ###
'use strict'

replyCodes = require('./replyCodes')
headersHelper = require('./headers')
util = require('util')


getErrorMessage = (err) ->
  if !err?
    return JSON.stringify(err)
  if err.message
    return err.message
  if err.toString() == '[object Object]'
    inspect = util.inspect(err, depth: null)
    return inspect.replace(/,?\n +\w+: undefined/g, '')  # filter out unnecessary fields
  else
    return err.toString()


class RetsError extends Error

  
class RetsReplyError extends RetsError
  constructor: (@retsMethod, @replyCode, @replyText, _headerInfo) ->
    @name = 'RetsReplyError'
    @replyTag = if replyCodes.tagMap[@replyCode]? then replyCodes.tagMap[@replyCode] else 'unknown reply code'
    @message = "RETS Server reply while attempting #{@retsMethod} - ReplyCode #{@replyCode} (#{@replyTag}); ReplyText: #{@replyText}"
    @headerInfo = headersHelper.processHeaders(_headerInfo)
    Error.captureStackTrace(this, RetsReplyError)


class RetsServerError extends RetsError
  constructor: (@retsMethod, @httpStatus, @httpStatusMessage, _headerInfo) ->
    @name = 'RetsServerError'
    @message = "RETS Server error while attempting #{@retsMethod} - HTTP Status #{@httpStatus} returned (#{@httpStatusMessage})"
    @headerInfo = headersHelper.processHeaders(_headerInfo)
    Error.captureStackTrace(this, RetsServerError)


class RetsProcessingError extends RetsError
  constructor: (@retsMethod, @sourceError, _headerInfo) ->
    @name = 'RetsProcessingError'
    @message = "Error while processing RETS response for #{@retsMethod} - #{getErrorMessage(@sourceError)}"
    @headerInfo = headersHelper.processHeaders(_headerInfo)
    Error.captureStackTrace(this, RetsProcessingError)


class RetsParamError extends RetsError
  constructor: (@message) ->
    @name = 'RetsParamError'
    Error.captureStackTrace(this, RetsParamError)

class RetsPermissionError extends RetsError
  constructor: (missing = []) ->
    @name = 'RetsPermissionError'
    @message = "Login was successful, but this account does not have the proper permissions."
    if missing.length
      @message += " Missing the following permissions: #{missing.join(', ')}"
    Error.captureStackTrace(this, RetsPermissionError)

ensureRetsError = (retsMethod, error, headerInfo) ->
  if error instanceof RetsError
    return error
  else
    return new RetsProcessingError(retsMethod, error, headerInfo)
    

module.exports = {
  RetsError
  RetsReplyError
  RetsServerError
  RetsProcessingError
  RetsParamError
  RetsPermissionError
  ensureRetsError
  getErrorMessage
}
