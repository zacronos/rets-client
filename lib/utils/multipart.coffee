### jshint node:true ###
### jshint -W097 ###
'use strict'

logger = require('winston')
MultipartParser = require('formidable/lib/multipart_parser').MultipartParser
Stream = require('stream').Stream
StringDecoder = require('string_decoder').StringDecoder
streamBuffers = require('stream-buffers')
Promise = require('bluebird')


# Multipart parser derived from formidable library. See https://github.com/felixge/node-formidable


parseMultipart = (buffer, _multipartBoundary) -> Promise.try () ->
  parser = getParser(_multipartBoundary)
  if parser instanceof Error
    return Promise.reject(parser)
  parser.write(buffer)
  dataBufferList = []
  for streamBuffer in parser.streamBufferList
    dataBufferList.push
      buffer: streamBuffer.streamBuffer.getContents()
      mime: streamBuffer.mime
      description: streamBuffer.description
      contentDescription: streamBuffer.contentDescription
      contentId: streamBuffer.contentId
      objectId: streamBuffer.objectId
  dataBufferList


getParser = (_multipartBoundary) ->
  streamBufferList = []
  parser = new MultipartParser()
  headerField = ''
  headerValue = ''
  part = {}
  encoding = 'utf8'
  ended = false
  maxFields = 1000
  maxFieldsSize = 2 * 1024 * 1024

  parser.onPartBegin = () ->
    part = new Stream()
    part.readable = true
    part.headers = {}
    part.name = null
    part.filename = null
    part.mime = null
    part.transferEncoding = 'binary'
    part.transferBuffer = ''
    headerField = ''
    headerValue = ''

  parser.onHeaderField = (b, start, end) ->
    headerField += b.toString(encoding, start, end)

  parser.onHeaderValue = (b, start, end) ->
    headerValue += b.toString(encoding, start, end)

  parser.onHeaderEnd = () =>
    headerField = headerField.toLowerCase()
    part.headers[headerField] = headerValue
    if headerField == 'content-disposition'
      m = headerValue.match(/\bname="([^"]+)"/i)
      if m
        part.name = m[1]
      part.filename = self._fileName(headerValue)
    else if headerField == 'content-type'
      part.mime = headerValue
    else if headerField == 'content-transfer-encoding'
      part.transferEncoding = headerValue.toLowerCase()
    headerField = ''
    headerValue = ''

  parser.onHeadersEnd = () ->
    switch part.transferEncoding
      
      when 'binary', '7bit', '8bit'
        parser.onPartData = (b, start, end) ->
          part.emit('data', b.slice(start, end))
        parser.onPartEnd = () ->
          part.emit('end')
      
      when 'base64'
        parser.onPartData = (b, start, end) ->
          part.transferBuffer += b.slice(start, end).toString('ascii')

          ###
           four bytes (chars) in base64 converts to three bytes in binary
           encoding. So we should always work with a number of bytes that
           can be divided by 4, it will result in a number of bytes that
           can be divided vy 3.
          ###

          offset = parseInt(part.transferBuffer.length / 4, 10) * 4
          part.emit('data', new Buffer(part.transferBuffer.substring(0, offset), 'base64'))
          part.transferBuffer = part.transferBuffer.substring(offset)

        parser.onPartEnd = () ->
          part.emit('data', new Buffer(part.transferBuffer, 'base64'))
          part.emit('end')

      else
        return new Error('unknown transfer-encoding')
    handlePart(part)

  parser.onEnd = () ->
    ended = true

  handlePart = (part) ->
    fieldsSize = 0
    if part.filename == undefined
      value = ''
      decoder = new StringDecoder(encoding)
      part.on 'data', (buffer) ->
        fieldsSize += buffer.length
        if fieldsSize > maxFieldsSize
          logger.error('maxFieldsSize exceeded, received ' + fieldsSize + ' bytes of field data')
          return
        value += decoder.write(buffer)
      return
    writableStreamBuffer = new (streamBuffers.WritableStreamBuffer)(
      initialSize: 100 * 1024
      incrementAmount: 10 * 1024
    )
    part.on 'data', (buffer) ->
      if buffer.length == 0
        return
      writableStreamBuffer.write(buffer)
    part.on 'end', ->
      streamBufferList.push
        streamBuffer: writableStreamBuffer
        mime: part.mime
        contentDescription: part.headers['content-description']
        contentId: part.headers['content-id']
        objectId: part.headers['object-id']

  parser.initWithBoundary _multipartBoundary
  parser.streamBufferList = streamBufferList
  parser

module.exports.parseMultipart = parseMultipart
