### jshint node:true ###
### jshint -W097 ###
'use strict'

MultipartParser = require('formidable/lib/multipart_parser').MultipartParser
Promise = require('bluebird')
through2 = require('through2')
debug = require('debug')('rets-client:multipart')
debugVerbose = require('debug')('rets-client:multipart:verbose')

retsParsing = require('./retsParsing')
errors = require('./errors')


# Multipart parser derived from formidable library. See https://github.com/felixge/node-formidable


getObjectStream = (headerInfo, stream, handler, options) -> new Promise (resolve, reject) ->
  multipartBoundary = headerInfo.contentType.match(/boundary="[^"]+"/ig)?[0].slice('boundary="'.length, -1)
  if !multipartBoundary
    multipartBoundary = headerInfo.contentType.match(/boundary=[^;]+/ig)?[0].slice('boundary='.length)
  if !multipartBoundary
    throw new errors.RetsProcessingError('getObject', 'Could not find multipart boundary', headerInfo)
  
  parser = new MultipartParser()
  objectStream = through2.obj()
  headerField = ''
  headerValue = ''
  headers = []
  bodyStream = null
  streamError = null
  done = false
  partDone = false
  flushed = false
  
  handleError = (err) ->
    debug("handleError: #{err.error||err}")
    bodyStream?.end()
    bodyStream = null
    if !objectStream
      return
    if !err.error || !err.headerInfo
      err = {error: err}
    objectStream.write(err)
  
  handleEnd = () ->
    if done && partDone && flushed && objectStream
      debug("handleEnd")
      objectStream.end()
      objectStream = null
    else
      debug("handleEnd not ready #{JSON.stringify({done, partDone, flushed, objectStream: !!objectStream})}")

  parser.onPartBegin = () ->
    debug("onPartBegin")
    object =
      buffer: null
      error: null
    headerField = ''
    headerValue = ''
    headers = []
    partDone = false

  parser.onHeaderField = (b, start, end) ->
    debugVerbose("onHeaderField: #{headerField}")
    headerField += b.toString('utf8', start, end)

  parser.onHeaderValue = (b, start, end) ->
    debugVerbose("onHeaderValue: #{headerValue}")
    headerValue += b.toString('utf8', start, end)

  parser.onHeaderEnd = () ->
    debug("onHeaderEnd: {#{headerField}: #{headerValue}}")
    headers.push(headerField)
    headers.push(headerValue)
    headerField = ''
    headerValue = ''

  parser.onHeadersEnd = () ->
    debug("onHeadersEnd: [#{headers.length/2} headers parsed]")
    bodyStream = through2()
    handler(headers, bodyStream, false, options)
    .then (object) ->
      objectStream?.write(object)
    .catch (err) ->
      handleError(errors.ensureRetsError('getObject', err, headers))
    .then () ->
      partDone = true
      handleEnd()
      
  parser.onPartData = (b, start, end) ->
    debugVerbose("onPartData")
    bodyStream?.write(b.slice(start, end))
    
  parser.onPartEnd = () ->
    debug("onPartEnd")
    bodyStream?.end()
    bodyStream = null

  parser.onEnd = () ->
    debug("onEnd")
    done = true
    handleEnd()

  parser.initWithBoundary(multipartBoundary)
  
  stream.on 'error', (err) ->
    debug("stream error")
    handleError(err)
    
  interceptor = (chunk, encoding, callback) ->
    parser.write(chunk)
    callback()
    
  flush = (callback) ->
    debug("stream flush")
    err = parser.end()
    if err
      handleError(new errors.RetsProcessingError('getObject', "Unexpected end of data: #{errors.getErrorMessage(err)}", headerInfo))
    flushed = true
    handleEnd()
    callback()
    
  stream.pipe(through2(interceptor, flush))
  resolve(objectStream)
    
module.exports.getObjectStream = getObjectStream
