### jshint node:true ###
### jshint -W097 ###
'use strict'

expat = require('node-expat')
through2 = require('through2')

errors = require('./errors')
replyCodes = require('./replyCodes')
hex2a = require('./hex2a')
headersHelper = require('./headers')


# Parsing as performed here and in the other modules of this project relies on some simplifying assumptions.  DO NOT
# COPY OR MODIFY THIS LOGIC BLINDLY!  It works correctly for well-formed XML which adheres to the RETS specifications,
# and does not attempt to check for or properly handle XML not of that form.  In particular, it does not keep track of
# the element stack to ensure elements (and text) are found only in the expected locations.


# a parser with some basic common functionality, intended to be extended for real use
getSimpleParser = (retsMethod, errCallback, headerInfo, parserEncoding='UTF-8') ->
  result =
    currElementName: null
    parser: new expat.Parser(parserEncoding)
    finish: () ->
      result.parser.removeAllListeners()
    status: null

  result.parser.once 'startElement', (name, attrs) ->
    if name != 'RETS'
      result.finish()
      errCallback(new errors.RetsProcessingError(retsMethod, 'Unexpected results. Please check the RETS URL.', headerInfo))

  result.parser.on 'startElement', (name, attrs) ->
    result.currElementName = name
    if name != 'RETS' && name != 'RETS-STATUS'
      return
    result.status = attrs
    if attrs.ReplyCode != '0' && attrs.ReplyCode != '20208'
      result.finish()
      errCallback(new errors.RetsReplyError(retsMethod, attrs.ReplyCode, attrs.ReplyText, headerInfo))

  result.parser.on 'error', (err) ->
    result.finish()
    errCallback(new errors.RetsProcessingError(retsMethod, "XML parsing error: #{errors.getErrorMessage(err)}", headerInfo))

  result.parser.on 'end', () ->
    result.finish()
    errCallback(new errors.RetsProcessingError(retsMethod, "Unexpected end of xml stream.", headerInfo))

  result


# parser that deals with column/data tags, as returned for metadata and search queries
getStreamParser = (retsMethod, metadataTag, rawData, parserEncoding='UTF-8') ->
  if metadataTag
    rawData = false
    result =
      rowsReceived: 0
      entriesReceived: 0
    delimiter = '\t'
  else
    result =
      rowsReceived: 0
      maxRowsExceeded: false
    delimiter = null
  columnText = null
  dataText = null
  columns = null
  currElementName = null
  headers = null

  parser = new expat.Parser(parserEncoding)
  retsStream = through2.obj()
  finish = (type, payload) ->
    parser.removeAllListeners()
    # ignore errors after this point
    parser.on('error', () -> ### noop ###)
    retsStream.write(type: type, payload: payload)
    retsStream.end()
  fail = (err) ->
    finish('error', err)
  writeOutput = (type, payload) ->
    retsStream.write(type: type, payload: payload)
  response = (response) ->
    headers = headersHelper.processHeaders(response.rawHeaders)
    writeOutput('headerInfo', headers)
  processStatus = (attrs) ->
    if attrs.ReplyCode != '0' && attrs.ReplyCode != '20208'
      return fail(new errors.RetsReplyError(retsMethod, attrs.ReplyCode, attrs.ReplyText, headers))
    status =
      replyCode: attrs.ReplyCode
      replyTag: replyCodes.tagMap[attrs.ReplyCode]
      replyText: attrs.ReplyText
    writeOutput('status', status)

  parser.once 'startElement', (name, attrs) ->
    if name != 'RETS'
      return fail(new errors.RetsProcessingError(retsMethod, 'Unexpected results. Please check the RETS URL.', headers))
    processStatus(attrs)
  
    parser.on 'startElement', (name, attrs) ->
      currElementName = name
      switch name
        when 'DATA'
          dataText = ''
        when 'COLUMNS'
          columnText = ''
        when metadataTag
          writeOutput('metadataStart', attrs)
          result.rowsReceived = 0
        when 'COUNT'
          ### Ignore count write when stream ended due to NO_RECORDS_FOUND (20201) error. ###
          if !retsStream.writable && parseInt(attrs.Records) == 0
            return false
          writeOutput('count', parseInt(attrs.Records))
        when 'MAXROWS'
          result.maxRowsExceeded = true
        when 'DELIMITER'
          delimiter = hex2a(attrs.value)
          writeOutput('delimiter', delimiter)
        when 'RETS-STATUS'
          processStatus(attrs)

  parser.on 'text', (text) ->
    switch currElementName
      when 'DATA'
        dataText += text
      when 'COLUMNS'
        columnText += text

  if rawData
    parser.on 'endElement', (name) ->
      currElementName = null
      switch name
        when 'DATA'
          writeOutput('data', dataText)
          result.rowsReceived++
        when 'COLUMNS'
          writeOutput('columns', columnText)
        when 'RETS'
          finish('done', result)
  else
    parser.on 'endElement', (name) ->
      currElementName = null
      switch name
        when 'DATA'
          if !columns
            return fail(new errors.RetsProcessingError(retsMethod, 'Failed to parse columns', headers))
          data = dataText.split(delimiter)
          model = {}
          i=1
          while i < columns.length-1
            model[columns[i]] = data[i]
            i++
          writeOutput('data', model)
          result.rowsReceived++
        when 'COLUMNS'
          if !delimiter
            return fail(new errors.RetsProcessingError(retsMethod, 'Failed to parse delimiter', headers))
          columns = columnText.split(delimiter)
          writeOutput('columns', columns)
        when metadataTag
          result.entriesReceived++
          writeOutput('metadataEnd', result.rowsReceived)
        when 'RETS'
          if metadataTag
            delete result.rowsReceived
          finish('done', result)

  parser.on 'error', (err) ->
    fail(new errors.RetsProcessingError(retsMethod, "XML parsing error: #{errors.getErrorMessage(err)}", headers))
  
  parser.on 'end', () ->
    # we remove event listeners upon success, so getting here implies failure
    fail(new errors.RetsProcessingError(retsMethod, "Unexpected end of xml stream.", headers))
  
  { parser, fail, retsStream, response }
  
  
module.exports =
  getSimpleParser: getSimpleParser
  getStreamParser: getStreamParser
