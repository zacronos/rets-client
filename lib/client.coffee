
crypto = require('crypto')
request = require('request')
Promise = require('bluebird')

auth = require('./auth.js')
metadata = require('./metadata.js')
search = require('./search.js')
object = require('./object.js')
appUtils = require('./utils.js')

URL_KEYS =
  GET_METADATA: "GetMetadata"
  GET_OBJECT: "GetObject"
  SEARCH: "Search"
  UPDATE: "Update"
  ACTION: "Action"
  LOGIN: "Login"
  LOGOUT: "Logout"
  
OTHER_KEYS =
  MEMBER_NAME: "MemberName"
  USER: "User"
  BROKER: "Broker"
  METADATA_VERSION: "MetadataVersion"
  METADATA_TIMESTAMP: "MetadataTimestamp"
  MIN_METADATA_TIMESTAMP: "MinMetadataTimestamp"
  RETS_VERSION: "retsVersion"
  RETS_SERVER: "retsServer"


class Client
  constructor: (@settings) ->
    @headers =
      'User-Agent': "Node-Rets/1.0"
      'RETS-Version': @settings.version || 'RETS/1.7.2'
      
    if @settings.userAgent
      # use specified user agent
      @headers['User-Agent'] = @settings.userAgent

      # add RETS-UA-Authorization header
      if @settings.userAgentPassword
        a1 = crypto.createHash('md5').update([@settings.userAgent, @settings.userAgentPassword].join(":")).digest('hex')
        retsUaAuth = crypto.createHash('md5').update([a1, "", @settings.sessionId || "", @settings.version || headers['RETS-Version']].join(":")).digest('hex')
        @headers['RETS-UA-Authorization'] = "Digest " + retsUaAuth

    @baseRetsSession = request.defaults
      jar: request.jar()
      headers: @headers

      
  login: () ->
    options =
      uri: @settings.loginUrl
    if @settings.username && @settings.password
      options.auth =
        'user': @settings.username
        'pass': @settings.password
        'sendImmediately': false
    Promise.fromNode (callback) =>
      auth.login @baseRetsSession.defaults(options), callback
    .then (systemData) =>
      @systemData = systemData
      @urls = {}
      for key,val in URL_KEYS
        if @systemData[URL_KEYS.GET_METADATA]
          @urls[URL_KEYS.GET_METADATA] = appUtils.getValidUrl(@systemData[URL_KEYS.GET_METADATA], @settings.loginUrl)
      @retsVersion = @systemData[OTHER_KEYS.RETS_VERSION]
      @retsServer = @systemData[OTHER_KEYS.RETS_SERVER]
      @memberName = @systemData[OTHER_KEYS.MEMBER_NAME]
      @user = @systemData[OTHER_KEYS.USER]
      @broker = @systemData[OTHER_KEYS.BROKER]
      @metadataVersion = @systemData[OTHER_KEYS.METADATA_VERSION]
      @metadataTimestamp = @systemData[OTHER_KEYS.METADATA_TIMESTAMP]
      @minMetadataTimestamp = @systemData[OTHER_KEYS.MIN_METADATA_TIMESTAMP]

      metadataModule = metadata @baseRetsSession.defaults uri: @systemData[URL_KEYS.GET_METADATA]
      @metadata = {}
      for own method of metadataModule
        @metadata[method] = Promise.promisify metadataModule[method], metadataModule
  
      searchModule = search @baseRetsSession.defaults uri: @systemData[URL_KEYS.SEARCH]
      @search = {}
      for own method of searchModule
        @search[method] = Promise.promisify searchModule[method], searchModule
  
      objectsModule = object @baseRetsSession.defaults uri: @systemData[URL_KEYS.GET_OBJECT]
      @objects = {}
      for own method of objectsModule
        @objects[method] = Promise.promisify objectsModule[method], objectsModule

      @logoutRequest = @baseRetsSession.defaults uri: @systemData[URL_KEYS.LOGOUT]
      
      return @

  # Logs the user out of the current session
  logout: () ->
    Promise.fromNode (callback) =>
      auth.logout(@logoutRequest, callback)

module.exports = Client
