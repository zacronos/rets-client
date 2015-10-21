### jshint node:true ###
### jshint -W097 ###
'use strict'

logger = require('winston')
Promise = require('bluebird')

retsParsing = require('./retsParsing')
retsHttp = require('./retsHttp')


###
# Executes RETS login routine.
###

login = (retsSession) ->
  retsHttp.callRetsMethod('login', Promise.promisify(retsSession), {})
  .then (retsResponse) -> new Promise (resolve, reject) ->
    systemData =
      retsVersion: retsResponse.response.headers['rets-version']
      retsServer: retsResponse.response.headers.server
    
    retsParser = retsParsing.getSimpleParser(reject)
    
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
    retsParser.parser.end()


###
# Logouts RETS user
###

logout = (retsSession) ->
  retsHttp.callRetsMethod('logout', Promise.promisify(retsSession), {})
  .then (result) ->
    logger.debug 'Logout success'


module.exports =
  login: login
  logout: logout
