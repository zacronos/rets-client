### jshint node:true ###
### jshint -W097 ###
'use strict'

MultipartParser = require('formidable/lib/multipart_parser').MultipartParser
Promise = require('bluebird')
through2 = require('through2')

retsParsing = require('./retsParsing')
errors = require('./errors')


# Multipart parser derived from formidable library. See https://github.com/felixge/node-formidable


getObjectStream = (headerInfo, stream, handler) -> new Promise (resolve, reject) ->
  multipartBoundary = headerInfo.contentType.match(/boundary="[^"]+"/ig)?[0].slice('boundary="'.length, -1)
  if !multipartBoundary
    multipartBoundary = headerInfo.contentType.match(/boundary=[^;]+/ig)?[0].slice('boundary='.length)
  if !multipartBoundary
    throw new errors.RetsProcessingError('getObject', 'Could not find multipart boundary', headerInfo)
  
  parser = new MultipartParser()
  objectStream = through2.obj()
  objectStreamDone = false
  headerField = ''
  headerValue = ''
  headers = []
  bodyStream = null
  streamError = null
  done = false
  partDone = false
  flushed = false
  
  objectStream.on 'end', () ->
    objectStreamDone = true
  
  handleError = (err) ->
    if bodyStream
      bodyStream.emit('error', err)
      bodyStream.end()
      bodyStream = null
    if objectStreamDone
      return
    if !err.error || !err.headerInfo
      err = {error: err}
    objectStream.write(err)
  
  handleEnd = () ->
    if done && partDone && flushed && !objectStreamDone
      objectStream.end()

  parser.onPartBegin = () ->
    object =
      buffer: null
      error: null
    headerField = ''
    headerValue = ''
    headers = []
    partDone = false

  parser.onHeaderField = (b, start, end) ->
    headerField += b.toString('utf8', start, end)

  parser.onHeaderValue = (b, start, end) ->
    headerValue += b.toString('utf8', start, end)

  parser.onHeaderEnd = () =>
    headers.push(headerField)
    headers.push(headerValue)
    headerField = ''
    headerValue = ''

  parser.onHeadersEnd = () ->
    bodyStream = through2()
    bodyStreamDone = false
    bodyStream.on 'end', () ->
      bodyStreamDone = true
    handler(headers, bodyStream)
    .then (object) ->
      if !objectStreamDone
        objectStream.write(object)
    .catch (err) ->
      handleError(errors.ensureRetsError('getObject', err, headers))
    .then () ->
      partDone = true
      handleEnd()
    .catch (error) ->
      # swallowing this error, it's already been reported
    parser.onPartData = (b, start, end) ->
      if !bodyStreamDone
        bodyStream.write(b.slice(start, end))
    parser.onPartEnd = () ->
      if !bodyStreamDone
        bodyStream.end()
      bodyStream = null

  parser.onEnd = () ->
    if done
      return
    done = true

  parser.initWithBoundary(multipartBoundary)
  
  stream.on 'error', (err) ->
    streamError = err
  interceptor = (chunk, encoding, callback) ->
    parser.write(chunk)
    callback()
  flush = (callback) ->
    try
      err = parser.end()
      if err
        handleError(new errors.RetsProcessingError('getObject', "Unexpected end of data: #{errors.getErrorMessage(err)}", headerInfo))
      flushed = true
      handleEnd()
    catch err2
      console.log('uncaught error is now caught: '+errors.getErrorMessage(err)+'\n'+(err2.stack || errors.getErrorMessage(err2)))
      # I don't know how the error is getting thrown, but it's already been handled by this point, so we can swallow it
  stream.pipe(through2(interceptor, flush))
  resolve(objectStream)
    
module.exports.getObjectStream = getObjectStream
