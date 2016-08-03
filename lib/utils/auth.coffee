### jshint node:true ###
### jshint -W097 ###
'use strict'

Promise = require('bluebird')

retsParsing = require('./retsParsing')
retsHttp = require('./retsHttp')
headersHelper = require('./headers')
errors = require('./errors')


###
# Executes RETS login routine.
###

login = (retsSession, client) ->
  retsHttp.callRetsMethod('login', Promise.promisify(retsSession), {})
  .then (retsResponse) -> new Promise (resolve, reject) ->
    headers = headersHelper.processHeaders(retsResponse.response.rawHeaders)
    if client.settings.userAgentPassword && headers.setCookie
      typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'
      if typeIsArray headers.setCookie
        headerCookies = headers.setCookie
      else
        headerCookies = [headers.setCookie];
      for headerCookie in headerCookies
        matches = headerCookie.match(/RETS\-Session\-ID=([^;]+);/)
        if matches
          client.settings.sessionId = matches[1]
          break
    systemData =
      retsVersion: headers.retsVersion
      retsServer: headers.server
    
    retsParser = retsParsing.getSimpleParser('login', reject, headers)
    
    gotData = false
    retsParser.parser.on 'text', (text) ->
      if retsParser.currElementName != 'RETS-RESPONSE'
        return
      gotData = true
      keyVals = text.split('\r\n')
      for keyVal in keyVals
        split = keyVal.split('=')
        if split.length > 1
          systemData[split[0].trim()] = split[1].trim()

    retsParser.parser.on 'endElement', (name) ->
      if name != 'RETS'
        return
      retsParser.finish()
      if !gotData
        reject(new errors.RetsProcessingError('login', 'Failed to parse data', headers))
      else
        resolve(systemData)

    retsParser.parser.write(retsResponse.body)
    retsParser.parser.end()


###
# Logouts RETS user
###

logout = (retsSession) ->
  retsHttp.callRetsMethod('logout', Promise.promisify(retsSession), {})


module.exports =
  login: login
  logout: logout
