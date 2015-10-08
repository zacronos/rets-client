### jshint node:true ###
### jshint -W097 ###
'use strict'

logger = require('winston')
Promise = require('bluebird')
xmlParser = Promise.promisify(require('xml2js').parseString)

utils = require('./utils')


###
# Executes RETS login routine.
###

login = (retsSession) ->
  logger.debug 'RETS method login'
  utils.callRetsMethod('login', Promise.promisify(retsSession), {})
  .then (result) ->
    xmlParser(result.body)
    .then (parsed) ->
      if !parsed || !parsed.RETS
        throw new Error('Unexpected results. Please check the RETS URL')
      keyVals = parsed.RETS['RETS-RESPONSE'][0].split('\r\n')
      systemData = {}
      for keyVal in keyVals
        split = keyVal.split('=')
        if split.length > 1
          systemData[split[0]] = split[1]
      systemData.retsVersion = result.response.headers['rets-version']
      systemData.retsServer = result.response.headers.server
      systemData


###
# Logouts RETS user
###

logout = (retsSession) ->
  logger.debug 'RETS method logout'
  utils.callRetsMethod('logout', Promise.promisify(retsSession), {})
  .then (result) ->
    logger.debug 'Logout success'


module.exports =
  login: login
  logout: logout
