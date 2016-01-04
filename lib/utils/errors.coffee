### jshint node:true ###
### jshint -W097 ###
'use strict'

replyCodes = require('./replyCodes')
headersHelper = require('./headers')


class RetsReplyError extends Error
  constructor: (@replyCode, @replyText, _headerInfo) ->
    @name = 'RetsReplyError'
    @replyTag = if replyCodes.tagMap[@replyCode]? then replyCodes.tagMap[@replyCode] else 'unknown reply code'
    @message = "RETS Server replied with an error code - ReplyCode #{@replyCode} (#{@replyTag}); ReplyText: #{@replyText}"
    @headerInfo = headersHelper.processHeaders(_headerInfo)
    Error.captureStackTrace(this, RetsReplyError)
  


class RetsServerError extends Error
  constructor: (@retsMethod, @httpStatus, @httpStatusMessage, _headerInfo) ->
    @name = 'RetsServerError'
    @message = "Error while attempting #{@retsMethod} - HTTP Status #{@httpStatus} returned (#{@httpStatusMessage})"
    @headerInfo = headersHelper.processHeaders(_headerInfo)
    Error.captureStackTrace(this, RetsServerError)


module.exports =
  RetsReplyError: RetsReplyError
  RetsServerError: RetsServerError
