### jshint node:true ###
### jshint -W097 ###
'use strict'

logger = require('winston')
MultipartParser = require('formidable/lib/multipart_parser').MultipartParser
Stream = require('stream').Stream
StringDecoder = require('string_decoder').StringDecoder
WritableStreamBuffer = require('stream-buffers').WritableStreamBuffer
Promise = require('bluebird')

retsParsing = require('./retsParsing')


# Multipart parser derived from formidable library. See https://github.com/felixge/node-formidable


_kebabToCamel = (str) ->
  if !str?
    return str
  str.toLowerCase().replace /\w-\w/g, (boundary) ->
    boundary.charAt(0) + boundary.charAt(2).toUpperCase()

parseMultipart = (buffer, _multipartBoundary) -> new Promise (resolve, reject) ->
  parser = new MultipartParser()
  encoding = 'utf8'
  partList = []
  headerField = ''
  headerValue = ''
  part = null
  done = false
  transferBuffer = null
  transferEncoding = null
  writableStreamBuffer = null

  parser.onPartBegin = () ->
    part =
      buffer: null
      error: null
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
      part.mime = headerValue.toLowerCase()
    else if headerField == 'content-transfer-encoding'
      transferEncoding = headerValue.toLowerCase()
    else
      part[_kebabToCamel(headerField)] = headerValue
    headerField = ''
    headerValue = ''

  parser.onHeadersEnd = () ->
    if done
      return
    
    if part.mime == 'text/xml'
      # can happen when there's an error that affects only 1 object in the multipart response
      retsParser = retsParsing.getSimpleParser (error) ->
        part.error = error
        partList.push(part)
      parser.onPartData = (b, start, end) ->
        retsParser.parser.write(b.slice(start, end))
      parser.onPartEnd = () ->
        retsParser.parser.end()
      return

    # this is the normal path -- probably an image object
    switch transferEncoding
      
      when 'binary', '7bit', '8bit'
        parser.onPartData = (b, start, end) ->
          writableStreamBuffer.write(b.slice(start, end))
        parser.onPartEnd = () ->
          part.buffer = writableStreamBuffer.getContents()
          partList.push(part)
      
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
          partList.push(part)

      else
        done = true
        reject(new Error("unknown content-transfer-encoding: #{JSON.stringify(transferEncoding)}"))

  parser.onEnd = () ->
    if done
      return
    done = true
    resolve(partList)

  parser.initWithBoundary(_multipartBoundary)
  parser.write(buffer)
  process.nextTick () ->
    err = parser.end()
    if err
      if done
        return
      done = true
      if partList.length == 0
        # we didn't get any valid results, so reject the whole request with an error
        reject(err)
      else
        # we want to return the results that we can, so just append the errored part to the end
        if partList[partList.length-1] == part
          part = {error: err}
        else
          part.error = err
        partList.push(part)
        resolve(partList)

module.exports.parseMultipart = parseMultipart
