### jshint node:true ###
### jshint -W097 ###
'use strict'

logger = require('winston')
streamBuffers = require('stream-buffers')
Promise = require('bluebird')

multipart = require('../utils/multipart')
retsHttp = require('../utils/retsHttp')


###
# Retrieves RETS object data.
#
# @param resourceType Rets resource type (ex: Property)
# @param objectType Rets object type (ex: LargePhoto)
# @param objectId Object identifier
#
# resolves to an object with the following fields:
#   contentType
#   data (buffer)
#   response (http response object)
###

getObject = (resourceType, objectType, objectId) ->
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
  
  #pipe object data to stream buffer
  new Promise (resolve, reject) =>
    contentType = null
    response = null
    done = false
    fail = (error) ->
      if done
        return
      done = true
      reject(error)
    req = retsHttp.streamRetsMethod('getObject', @retsSession, options, fail)
    req.on('error', fail)
    req.on 'response', (_response) ->
      response = _response
      contentType = _response.headers['content-type']
    req.on 'end', () ->
      if done
        return
      done = true
      resolve
        contentType: contentType
        data: writableStreamBuffer.getContents()
        response: response
    req.pipe(writableStreamBuffer)


###
# Helper that retrieves a list of photo objects.
#
# @param resourceType Rets resource type (ex: Property)
# @param photoType Photo object type, based on getObjects meta call (ex: LargePhoto, Photo)
# @param matrixId Photo source identifier (listing id, agent id, etc).
#
# Each item in resolved data list is an object with the following data elements:
#   buffer: <data buffer>,
#   mime: <data buffer mime type>,
#   contentId: <photo source identifier, i.e. resource-entity-id>,
#   objectId: <identifier for this photo within the resource>
#   ...: other elements may be provided as well if sent by the server, such as contentDescription, dispositionType, etc
###

getPhotos = (resourceType, photoType, matrixId) ->
  @getObject(resourceType, photoType, matrixId + ':*')
  .then (result) ->
    multipartBoundary = result.contentType.match(/boundary=(?:"([^"]+)"|([^;]+))/ig)[0]?.match(/[^boundary=^"]\w+[^"]/ig)?[0]
    if !multipartBoundary
      throw new Error('Could not find multipart boundary')
    multipart.parseMultipart(new Buffer(result.data), multipartBoundary)
    .catch (err) ->
      logger.error err
      throw new Error('Error parsing multipart data')


module.exports = (_retsSession) ->
  if !_retsSession
    throw new Error('System data not set; invoke login().')
  retsSession: _retsSession
  getObject: getObject
  getPhotos: getPhotos
