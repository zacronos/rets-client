### jshint node:true ###
### jshint -W097 ###
'use strict'

logger = require('winston')
MultipartParser = require('formidable/lib/multipart_parser').MultipartParser
Stream = require('stream').Stream
StringDecoder = require('string_decoder').StringDecoder
WritableStreamBuffer = require('stream-buffers').WritableStreamBuffer
Promise = require('bluebird')


# Multipart parser derived from formidable library. See https://github.com/felixge/node-formidable


_kebabToCamel = (str) ->
  str.toLowerCase().replace /\w-\w/g, (boundary) ->
    boundary.charAt(0) + boundary.charAt(2).toUpperCase()

parseMultipart = (buffer, _multipartBoundary) -> new Promise (resolve, reject) ->
  parser = new MultipartParser()
  encoding = 'utf8'
  bufferList = []
  headerField = ''
  headerValue = ''
  part = null
  done = false
  transferBuffer = null
  transferEncoding = null
  writableStreamBuffer = null

  parser.onPartBegin = () ->
    part = {}
    transferEncoding = 'binary'
    transferBuffer = ''
    headerField = ''
    headerValue = ''
    writableStreamBuffer = new WritableStreamBuffer
      initialSize: 100 * 1024
      incrementAmount: 10 * 1024

  parser.onHeaderField = (b, start, end) ->
    headerField += b.toString(encoding, start, end)

  parser.onHeaderValue = (b, start, end) ->
    headerValue += b.toString(encoding, start, end)

  parser.onHeaderEnd = () =>
    headerField = headerField.toLowerCase()
    if headerField == 'content-disposition'
      dispositions = headerValue.split(/\s*;\s*/)
      for disposition,i in dispositions
        if i == 0
          part['dispositionType'] = disposition
        else
          split = disposition.indexOf('=')
          if split > -1
            paramName = disposition.substr(0, split)
            if disposition.charAt(split+1) == '"'
              split++
            end = disposition.length
            if disposition.charAt(disposition.length-1) == '"'
              end--
            paramValue = disposition.substring(split+1, end)
            part[_kebabToCamel(paramName)] = paramValue
    else if headerField == 'content-type'
      part.mime = headerValue
    else if headerField == 'content-transfer-encoding'
      transferEncoding = headerValue.toLowerCase()
    else
      part[_kebabToCamel(headerField)] = headerValue
    headerField = ''
    headerValue = ''

  parser.onHeadersEnd = () ->
    if done
      return
    switch transferEncoding
      
      when 'binary', '7bit', '8bit'
        parser.onPartData = (b, start, end) ->
          writableStreamBuffer.write(b.slice(start, end))
        parser.onPartEnd = () ->
          part.buffer = writableStreamBuffer.getContents()
          bufferList.push(part)
      
      when 'base64'
        # base64 encoding has 4 characters for every three bytes of binary encoding; therefore you
        # can only safely decode from base64 in multiples of 4-character chunks
        
        parser.onPartData = (b, start, end) ->
          transferBuffer += b.slice(start, end).toString('ascii')
          offset = Math.floor(transferBuffer.length / 4) * 4
          writableStreamBuffer.write(new Buffer(transferBuffer.substring(0, offset), 'base64'))
          transferBuffer = transferBuffer.substring(offset)

        parser.onPartEnd = () ->
          writableStreamBuffer.write(new Buffer(transferBuffer, 'base64'))
          part.buffer = writableStreamBuffer.getContents()
          bufferList.push(part)

      else
        done = true
        reject(new Error("unknown content-transfer-encoding: #{JSON.stringify(transferEncoding)}"))

  parser.onEnd = () ->
    resolve(bufferList)

  parser.initWithBoundary(_multipartBoundary)
  parser.write(buffer)
  err = parser.end()
  if err
    if done
      return
    done = true
    reject(err)

module.exports.parseMultipart = parseMultipart
