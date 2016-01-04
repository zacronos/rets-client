### jshint node:true ###
### jshint -W097 ###
'use strict'

MultipartParser = require('formidable/lib/multipart_parser').MultipartParser
Promise = require('bluebird')
through2 = require('through2')

retsParsing = require('./retsParsing')


# Multipart parser derived from formidable library. See https://github.com/felixge/node-formidable


getObjectStream = (headerInfo, stream, handler) -> new Promise (resolve, reject) ->
  multipartBoundary = headerInfo.contentType.match(/boundary="[^"]+"/ig)?[0].slice('boundary="'.length, -1)
  if !multipartBoundary
    multipartBoundary = headerInfo.contentType.match(/boundary=[^;]+/ig)?[0].slice('boundary='.length)
  if !multipartBoundary
    throw new Error('Could not find multipart boundary')
  
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
    if bodyStream
      bodyStream.emit('error', err)
      bodyStream.end()
      bodyStream = null
    if !err.error || !err.headerInfo
      err = {error: err}
    objectStream.write(err)
  
  handleEnd = () ->
    if done && partDone && flushed
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
    handler(headers, bodyStream)
    .then (object) ->
      objectStream.write(object)
    .catch handleError
    .then () ->
      partDone = true
      handleEnd()
    parser.onPartData = (b, start, end) ->
      bodyStream.write(b.slice(start, end))
    parser.onPartEnd = () ->
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
    err = parser.end()
    if err
      handleError(new Error("Unexpected end of data: #{err}"))
    flushed = true
    handleEnd()
  stream.pipe(through2(interceptor, flush))
  resolve(objectStream)
    
module.exports.getObjectStream = getObjectStream
