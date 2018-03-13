### jshint node:true ###
### jshint -W097 ###
'use strict'

urlUtil = require('url')


# Returns a valid url for use with RETS server. If target url just contains a path, fullURL's protocol and host will be utilized.
normalizeUrl = (targetUrl, fullUrl) ->
  loginUrlObj = urlUtil.parse(fullUrl, true, true)
  targetUrlObj = urlUtil.parse(targetUrl, true, true)
  if targetUrlObj.host != null
    return targetUrl
  fixedUrlObj =
    protocol: loginUrlObj.protocol
    slashes: true
    host: loginUrlObj.host
    pathname: targetUrlObj.pathname
    query: targetUrlObj.query
  urlUtil.format(fixedUrlObj)

  
module.exports = normalizeUrl
