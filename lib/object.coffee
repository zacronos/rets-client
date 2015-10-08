### jshint node:true ###
### jshint -W097 ###
'use strict'

logger = require('winston')
streamBuffers = require('stream-buffers')
Promise = require('bluebird')

multipart = require('./multipart')


###
# Retrieves RETS object data.
#
# @param resourceType Rets resource type (ex: Property)
# @param objectType Rets object type (ex: LargePhoto)
# @param objectId Object identifier
###

getObject = (resourceType, objectType, objectId) ->
  logger.debug 'RETS method getObject'
  if !resourceType
    throw new Error('Resource type id is required')
  if !objectType
    throw new Error('Object type id is required')
  if !objectId
    throw new Error('Object id is required')
  options =
    Type: objectType
    Id: objectId
    Resource: resourceType
  
  # prepare stream buffer for object data
  writableStreamBuffer = new (streamBuffers.WritableStreamBuffer)(
    initialSize: 100 * 1024
    incrementAmount: 10 * 1024)
  req = @retsSession(options)
  
  #pipe object data to stream buffer
  new Promise (resolve, reject) ->
    req.pipe(writableStreamBuffer)
    req.on('error', reject)
    contentType = null
    req.on 'response', (_response) ->
      contentType = _response.headers['content-type']
    req.on 'end', ->
      resolve
        contentType: contentType
        data: writableStreamBuffer.getContents()

###
# Helper that retrieves a list of photo objects.
#
# @param resourceType Rets resource type (ex: Property)
# @param photoType Photo object type, based on getObjects meta call (ex: LargePhoto, Photo)
# @param matrixId Photo matrix identifier.
#
# Each item in resolved data list is an object with the following data elements:
#   buffer: <data buffer>,
#   mime: <data buffer mime type>,
#   description: <data description>,
#   contentDescription: <data content description>,
#   contentId: <content identifier>,
#   objectId: <object identifier>
###

getPhotos = (resourceType, photoType, matrixId) ->
  @getObject(resourceType, photoType, matrixId + ':*')
  .then (result) ->
    multipartBoundary = result.contentType.match(/boundary=(?:"([^"]+)"|([^;]+))/ig)[0].match(/[^boundary=^"]\w+[^"]/ig)[0]
    if !multipartBoundary
      throw new Error('Could not find multipart boundary')
    multipart.parseMultipart(new Buffer(result.data), multipartBoundary)
    .catch (err) ->
      logger.error err
      throw new Error('Error parsing multipart data')


module.exports = (_retsSession) ->
  if !_retsSession
    throw new Error('System data not set; invoke login().')
  retsSession: Promise.promisify(_retsSession)
  getObject: getObject
  getPhotos: getPhotos
