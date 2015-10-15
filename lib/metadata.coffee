### jshint node:true ###
### jshint -W097 ###
'use strict'

logger = require('winston')
Promise = require('bluebird')
expat = require('node-expat')

utils = require('./utils')
replycodes = require('./replycodes')


_getParsedMetadataFactory = (retsSession, type, format='COMPACT') ->
  (id, classType) -> Promise.try () ->
    if !id
      throw new Error('Resource type id is required (or for some types of metadata, "0" retrieves for all resource types)')
    options =
      Type: type
      Id: if classType then "#{id}:#{classType}" else id
      Format: format
    logger.debug('RETS getMetadata', options)
    utils.callRetsMethod('getMetadata', retsSession, options)
    .then (result) ->
      parseXmlResponse(result.body, type)


_getParsedAllMetadataFactory = (retsSession, type, format='COMPACT') ->
  options =
    Type: type
    Id: '0'
    Format: format
  () -> Promise.try () ->
    logger.debug('RETS getMetadata', options)
    utils.callRetsMethod('getMetadata', retsSession, options)
    .then (result) ->
      parseXmlResponse(result.body, type)


# for performance, sort switch options by frequency within expected XML
parseXmlResponse = (rawXml, subtag) -> new Promise (resolve, reject) ->
  result =
    results: []
    type: subtag
  columnText = null
  dataText = null
  columns = null
  currEntry = null
  retsParser = utils.getBaseObjectParser(reject)

  retsParser.parser.on 'startElement', (name, attrs) ->
    switch name
      when 'DATA'
        dataText = ''
      when subtag
        currEntry =
          info: attrs
          metadata: []
        result.results.push(currEntry)
      when 'COLUMNS'
        columnText = ''

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
        data = dataText.split('\t')
        model = {}
        i=1
        while i < columns.length-1
          model[columns[i]] = data[i]
          i++
        currEntry.metadata.push(model)
      when 'COLUMNS'
        columns = columnText.split('\t')
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

      

###
# Retrieves RETS Metadata.
#
# @param type Metadata type (i.e METADATA-RESOURCE, METADATA-CLASS)
# @param id Metadata id
# @param format Data format (i.e. COMPACT, COMPACT-DECODED), defaults to 'COMPACT'
###

getMetadata = (type, id, format='COMPACT') -> Promise.try () =>
  logger.debug('RETS getMetadata', type, id, format)
  if !type
    throw new Error('Metadata type is required')
  if !id
    throw new Error('Resource type id is required (or for some types of metadata, "0" retrieves for all resource types)')
  options =
    Type: type
    Id: id
    Format: format
  utils.callRetsMethod('getMetadata', @retsSession, options)
  .then (result) ->
    result.body


###
# Helper that retrieves RETS system metadata
###

getSystem = () ->
  @getMetadata('METADATA-SYSTEM')
  .then (rawXml) -> new Promise (resolve, reject) ->
    result = {}
    retsParser = utils.getBaseObjectParser(reject)

    gotMetaDataInfo = false
    gotSystemInfo = false
    retsParser.parser.on 'startElement', (name, attrs) ->
      switch name
        when 'METADATA-SYSTEM'
          gotMetaDataInfo = true
          result.metadataVersion = attrs.Version
          result.metadataDate = attrs.Date
        when 'SYSTEM'
          gotSystemInfo = true
          result.systemId = attrs.SystemID
          result.systemDescription = attrs.SystemDescription

    retsParser.parser.on 'endElement', (name) ->
      if name != 'RETS'
        return
      retsParser.finish()
      if !gotSystemInfo || !gotMetaDataInfo
        reject(new Error('Failed to parse data'))
      else
        resolve(result)
    
    retsParser.parser.write(rawXml)


module.exports = (_retsSession) ->
  _retsSession = Promise.promisify(_retsSession)
  if !_retsSession
    throw new Error('System data not set; invoke login().')
  retsSession: _retsSession
  getMetadata: getMetadata
  getSystem: getSystem
  getResources:       _getParsedMetadataFactory(_retsSession, 'METADATA-RESOURCE')
  getForeignKeys:     _getParsedMetadataFactory(_retsSession, 'METADATA-FOREIGNKEYS')
  getClass:           _getParsedMetadataFactory(_retsSession, 'METADATA-CLASS')
  getTable:           _getParsedMetadataFactory(_retsSession, 'METADATA-TABLE')
  getLookups:         _getParsedMetadataFactory(_retsSession, 'METADATA-LOOKUP')
  getLookupTypes:     _getParsedMetadataFactory(_retsSession, 'METADATA-LOOKUP_TYPE')
  getObject:          _getParsedMetadataFactory(_retsSession, 'METADATA-OBJECT')
  getAllForeignKeys:  _getParsedAllMetadataFactory(_retsSession, 'METADATA-FOREIGNKEYS')
  getAllClass:        _getParsedAllMetadataFactory(_retsSession, 'METADATA-CLASS')
  getAllTable:        _getParsedAllMetadataFactory(_retsSession, 'METADATA-TABLE')
  getAllLookups:      _getParsedAllMetadataFactory(_retsSession, 'METADATA-LOOKUP')
  getAllLookupTypes:  _getParsedAllMetadataFactory(_retsSession, 'METADATA-LOOKUP_TYPE')
