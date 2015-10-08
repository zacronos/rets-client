### jshint node:true ###
### jshint -W097 ###
'use strict'

logger = require('winston')
Promise = require('bluebird')
xmlParser = Promise.promisify(require('xml2js').parseString)

utils = require('./utils')


_getParsedMetadataFactory = (retsSession, type, format='COMPACT') ->
  (id) -> Promise.try () ->
    if !id
      throw new Error('Resource type id is required (or for some types of metadata, "0" retrieves for all resource types)')
    options =
      Type: type
      Id: id
      Format: format
    logger.debug('RETS getMetadata', options)
    utils.callRetsMethod('getMetadata', retsSession, options)
    .then (result) ->
      utils.parseCompact(result.body, type)


_getParsedAllMetadataFactory = (retsSession, type, format='COMPACT') ->
  options =
    Type: type
    Id: '0'
    Format: format
  () -> Promise.try () ->
    logger.debug('RETS getMetadata', options)
    utils.callRetsMethod('getMetadata', retsSession, options)
    .then (result) ->
      utils.parseCompact(result.body, type)


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
  .then xmlParser
  .then utils.replyCodeCheck
  .then (parsedXml) ->
    systemData = result.RETS['METADATA-SYSTEM']?[0]
    if !systemData
      throw new Error("Failed to parse system XML: #{systemData}")
    metadataVersion: systemData.$.Version
    metadataDate: systemData.$.Date
    systemId: systemData.SYSTEM[0].$.SystemID
    systemDescription: systemData.SYSTEM[0].$.SystemDescription


module.exports = (_retsSession) ->
  _retsSession = Promise.promisify(_retsSession)
  if !_retsSession
    throw new Error('System data not set; invoke login().')
  retsSession: _retsSession
  getMetadata: getMetadata
  getSystem: getSystem
  getResources:       _getParsedMetadataFactory(_retsSession, 'METADATA-RESOURCE')
  getAllForeignKeys:  _getParsedAllMetadataFactory(_retsSession, 'METADATA-FOREIGNKEYS')
  getForeignKeys:     _getParsedMetadataFactory(_retsSession, 'METADATA-FOREIGNKEYS')
  getAllClass:        _getParsedAllMetadataFactory(_retsSession, 'METADATA-CLASS')
  getClass:           _getParsedMetadataFactory(_retsSession, 'METADATA-CLASS')
  getAllTable:        _getParsedAllMetadataFactory(_retsSession, 'METADATA-TABLE')
  getTable:           _getParsedMetadataFactory(_retsSession, 'METADATA-TABLE')
  getAllLookups:      _getParsedAllMetadataFactory(_retsSession, 'METADATA-LOOKUP')
  getLookups:         _getParsedMetadataFactory(_retsSession, 'METADATA-LOOKUP')
  getAllLookupTypes:  _getParsedAllMetadataFactory(_retsSession, 'METADATA-LOOKUP_TYPE')
  getLookupTypes:     _getParsedMetadataFactory(_retsSession, 'METADATA-LOOKUP_TYPE')
  getObject:          _getParsedMetadataFactory(_retsSession, 'METADATA-OBJECT')
