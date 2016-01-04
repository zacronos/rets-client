### jshint node:true ###
### jshint -W097 ###
'use strict'


_camelize = (str) ->
  str.replace /([A-Z]{2,})/g, (match) ->
    return match[0].toUpperCase()+match[1..].toLowerCase()
  .replace /(?:^\w|[A-Z]|\b\w|\s+)/g, (match, index) ->
    if +match == 0
      return ''
    if index == 0 then match.toLowerCase() else match.toUpperCase()
  .replace(/\W/g, '')


_setValue = (obj, key, value) ->
  if !obj[key]?
    obj[key] = value
  else if typeof(obj[key]) == 'string'
    obj[key] = [obj[key], value]
  else  # array
    obj[key].push(value)


processHeaders = (headers) ->
  if !headers?
    return {}
  if !Array.isArray(headers)
    return headers
  headerInfo = {}
      
  for field,i in headers by 2
    value = headers[i+1]
    fieldLower = field.toLowerCase()
    if fieldLower == 'content-disposition'
      dispositions = value.split(/\s*;\s*/)
      for disposition,i in dispositions
        if i == 0
          _setValue(headerInfo, 'dispositionType', disposition)
        else
          split = disposition.indexOf('=')
          if split > -1
            paramName = disposition.substr(0, split)
            if disposition.charAt(split+1) == '"'
              split++
            end = disposition.length
            if disposition.charAt(disposition.length-1) == '"'
              end--
            paramValue = disposition.substring(split+1, end)
            _setValue(headerInfo, _camelize(paramName), paramValue)
    else if fieldLower == 'content-transfer-encoding'
      _setValue(headerInfo, 'transferEncoding', value.toLowerCase())
    else
      _setValue(headerInfo, _camelize(field), value)
  
  if headerInfo.objectData?
    if Array.isArray(headerInfo.objectData)
      objectDataArray = headerInfo.objectData
    else
      objectDataArray = [headerInfo.objectData]
    objectData = {}
    for od in headerInfo.objectData
      split = od.indexOf('=')
      _setValue(objectData, _camelize(od.substr(0, split)), od.substr(split+1))
    headerInfo.objectData = objectData
  
  return headerInfo

module.exports.processHeaders = processHeaders
