### jshint node:true ###
### jshint -W097 ###
'use strict'


hex2a = (hex) ->
  if !hex
    return null
  
  # force conversion
  hex = hex.toString()
  
  str = ''
  i = 0
  while i < hex.length
    str += String.fromCharCode(parseInt(hex.substr(i, 2), 16))
    i += 2
  str

module.exports = hex2a
