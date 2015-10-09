### jshint node:true ###
### jshint -W097 ###
'use strict'

urlUtil = require('url')
Promise = require('bluebird')
logger = require('winston')
xmlParser = Promise.promisify(require('xml2js').parseString)

replycodes = require('./replycodes')


replyCodeCheck = (result) -> Promise.try () ->
  replyCode = result.RETS.$.ReplyCode
  # I suspect we'll want to allow 20208 replies through as well, but I'll wait to handle that until I can see
  # it in action myself or get info (or a PR) from someone else who can 
  if replyCode == '0'
    return result
    
  replyText = result.RETS.$.ReplyText
  replyTag = if replycodes.tagMap[replyCode]? then ' (' + replycodes.tagMap[replyCode] + ')' else ''
  error = new Error('RETS Server returned an error - ReplyCode ' + replyCode + replyTag + '; ReplyText: ' + replyText)
  error.replyCode = replyCode
  error.replyText = replyText
  error.replyTag = replyTag
  throw error

  
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
      error = new Error("RETS #{methodName} returned unexpected status code: " + response.statusCode)
      logger.debug "RETS #{methodName} error:\n" + error.message
      return Promise.reject(error)
    response: response
    body: body


croppedSlice = (data, delimiter) ->
  crop = delimiter.length
  data.slice(crop, -crop).split(delimiter)


parseCompact = (rawXml, subtag) -> Promise.try () ->
  xmlParser(rawXml)
  .then replyCodeCheck
  .then (parsedXml) ->
    result = {}
    if subtag
      resultBase = parsedXml.RETS[subtag]?[0]
      if !resultBase
        throw new Error("Failed to parse #{subtag} XML: #{resultBase}")
      delimiter = '\t'
      result.info = resultBase.$
      result.type = subtag
    else
      resultBase = parsedXml.RETS
      delimiter = hex2a(parsedXml.RETS.DELIMITER?[0]?.$?.value)
      if !delimiter
        throw new Error('No specified delimiter.')
      result.count = parsedXml.RETS.COUNT?[0]?.$?.Records
      result.maxRowsExceeded = parsedXml.RETS.MAXROWS?
    
    rawColumns = resultBase.COLUMNS?[0]
    if !rawColumns
      throw new Error("Failed to parse columns XML: #{resultBase.COLUMNS}")
    rawData = resultBase.DATA
    if !rawData?.length
      throw new Error("Failed to parse data XML: #{rawData}")
    
    columns = croppedSlice(rawColumns, delimiter)
    results = []
    for row in rawData
      data = croppedSlice(row, delimiter)
      model = {}
      for column,i in columns
        model[column] = data[i]
      results.push model
    result.results = results
    result.replyCode = parsedXml.RETS.$.ReplyCode
    result.replyTag = replycodes.tagMap[parsedXml.RETS.$.ReplyCode]
    result.replyText = parsedXml.RETS.$.ReplyText
    result


module.exports = 
  replyCodeCheck: replyCodeCheck
  hex2a: hex2a
  getValidUrl: getValidUrl
  croppedSlice: croppedSlice
  callRetsMethod: callRetsMethod
  parseCompact: parseCompact
