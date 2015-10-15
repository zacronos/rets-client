### jshint node:true ###
### jshint -W097 ###
'use strict'

logger = require('winston')
Promise = require('bluebird')

utils = require('./utils')
replycodes = require('./replycodes')


setDefaults = (options, defaults) ->
  if !options
    return options
  result = {}
  for own key of options
    result[key] = options[key]
  for own key of defaults when key not of result
    result[key] = defaults[key]
  result


#default query parameters
queryOptionsDefaults =
  queryType: 'DMQL2'
  format: 'COMPACT-DECODED'
  count: 1
  standardNames: 0
  restrictedIndicator: '***'
  limit: 'NONE'

###
# Invokes RETS search operation.
#
# @param _queryOptions Search query options.
#    See RETS specification for query options.
#
#    Default values for query params:
#
#       queryType:'DMQL2',
#       format:'COMPACT-DECODED',
#       count:1,
#       standardNames:0,
#       restrictedIndicator:'***',
#       limit:"NONE"
###

searchRets = (queryOptions) -> Promise.try () =>
  logger.debug 'RETS method search'
  if !queryOptions
    throw new Error('queryOptions is required.')
  if !queryOptions.searchType
    throw new Error('searchType is required (ex: Property')
  if !queryOptions.class
    throw new Error('class is required (ex: RESI)')
  if !queryOptions.query
    throw new Error('query is required (ex: (MatrixModifiedDT=2014-01-01T00:00:00.000+) )')
  finalQueryOptions = setDefaults(queryOptions, queryOptionsDefaults)
  utils.callRetsMethod('search', @retsSession, finalQueryOptions)
  .then (result) ->
    result.body

###
#
# Helper that performs a targeted RETS query and parses results.
#
# @param searchType Rets resource type (ex: Property)
# @param classType Rets class type (ex: RESI)
# @param query Rets query string. See RETS specification - (ex: MatrixModifiedDT=2014-01-01T00:00:00.000+)
# @param options Search query options (optional).
#    See RETS specification for query options.
#
#    Default values for query params:
#
#       queryType:'DMQL2',
#       format:'COMPACT-DECODED',
#       count:1,
#       standardNames:0,
#       restrictedIndicator:'***',
#       limit:"NONE"
#
#       Please note that queryType and format are immutable.
###

query = (resourceType, classType, queryString, options) -> Promise.try () =>
  baseOpts =
    searchType: resourceType
    class: classType
    query: queryString
  finalQueryOptions = setDefaults(baseOpts, options)
  
  # make sure queryType and format will use the searchRets defaults
  delete finalQueryOptions.queryType
  delete finalQueryOptions.format
  @searchRets(finalQueryOptions)
  .then parseXmlResponse
  


# for performance, sort switch options by frequency within expected XML
parseXmlResponse = (rawXml) -> new Promise (resolve, reject) ->
  result =
    maxRowsExceeded: false
    results: []
  columnText = null
  dataText = null
  columns = null
  delimiter = null
  retsParser = utils.getBaseObjectParser(reject)

  retsParser.parser.on 'startElement', (name, attrs) ->
    switch name
      when 'DATA'
        dataText = ''
      when 'COLUMNS'
        columnText = ''
      when 'COUNT'
        result.count = attrs.Records
      when 'MAXROWS'
        result.maxRowsExceeded = true
      when 'DELIMITER'
        delimiter = utils.hex2a(attrs.value)

  retsParser.parser.on 'text', (text) ->
    switch retsParser.currElementName
      when 'DATA'
        dataText += text
      when 'COLUMNS'
        columnText += text

  retsParser.parser.on 'endElement', (name) ->
    switch name
      when 'DATA'
        if !columns
          retsParser.finish()
          return reject(new Error('Failed to parse columns'))
        data = dataText.split(delimiter)
        model = {}
        i=1
        while i < columns.length-1
          model[columns[i]] = data[i]
          i++
        result.results.push(model)
      when 'COLUMNS'
        if !delimiter
          retsParser.finish()
          return reject(new Error('Failed to parse delimiter'))
        columns = columnText.split(delimiter)
      when 'RETS'
        retsParser.finish()
        if result.results.length == 0
          reject(new Error('Failed to parse data'))
        else
          result.replyCode = retsParser.status.ReplyCode
          result.replyTag = replycodes.tagMap[retsParser.status.ReplyCode]
          result.replyText = retsParser.status.ReplyText
          resolve(result)

  retsParser.parser.write(rawXml)
    

module.exports = (_retsSession) ->
  if !_retsSession
    throw new Error('System data not set; invoke login().')
  retsSession: Promise.promisify(_retsSession)
  searchRets: searchRets
  query: query
