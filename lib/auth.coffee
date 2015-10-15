### jshint node:true ###
### jshint -W097 ###
'use strict'

logger = require('winston')
Promise = require('bluebird')

utils = require('./utils')


###
# Executes RETS login routine.
###

login = (retsSession) ->
  logger.debug 'RETS method login'
  utils.callRetsMethod('login', Promise.promisify(retsSession), {})
  .then (retsResponse) -> new Promise (resolve, reject) ->
    systemData =
      retsVersion: retsResponse.response.headers['rets-version']
      retsServer: retsResponse.response.headers.server
    
    retsParser = utils.getBaseObjectParser(reject)
    
    gotData = false
    retsParser.parser.on 'text', (text) ->
      if retsParser.currElementName != 'RETS-RESPONSE'
        return
      gotData = true
      keyVals = text.split('\r\n')
      for keyVal in keyVals
        split = keyVal.split('=')
        if split.length > 1
          systemData[split[0]] = split[1]

    retsParser.parser.on 'endElement', (name) ->
      if name != 'RETS'
        return
      retsParser.finish()
      if !gotData
        reject(new Error('Failed to parse data'))
      else
        resolve(systemData)

    retsParser.parser.write(retsResponse.body)

###
# Logouts RETS user
###

logout = (retsSession) ->
  logger.debug 'RETS method logout'
  utils.callRetsMethod('logout', Promise.promisify(retsSession), {})
  .then (result) ->
    logger.debug 'Logout success'
    console.log(result.body)


module.exports =
  login: login
  logout: logout
