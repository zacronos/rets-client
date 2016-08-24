### jshint node:true ###
### jshint -W097 ###
'use strict'


errors = require('./errors')


# need to make a new object as we merge, as we don't want to modify the user's object
mergeOptions = (args...) ->
  if args.length == 0
    return {}
  
  result = {}
  # start at the end, so that values from earlier options objects overwrite and have priority
  for index in [args.length-1..0]
    options = args[index]
    for own key of options
      result[key] = options[key]
  
  result


# default query parameters
_queryOptionsDefaults =
  queryType: 'DMQL2'
  format: 'COMPACT-DECODED'
  count: 1
  standardNames: 0
  restrictedIndicator: '***'
  limit: 'NONE'

capitalizeFirstLetter = (string) ->
  string.charAt(0).toUpperCase() + string.slice(1);

remapKeys = (obj) ->
  result = {}
  for key, value of obj
    result[capitalizeFirstLetter(key)] = value
  result

normalizeOptions = (queryOptions) ->
  if !queryOptions
    throw errors.RetsParamError('search', 'queryOptions is required.')
  if !queryOptions.searchType
    throw errors.RetsProcessingError('search', 'searchType is required (ex: Property')
  if !queryOptions.class
    throw errors.RetsProcessingError('search', 'class is required (ex: RESI)')
  if !queryOptions.query
    throw errors.RetsProcessingError('search', 'query is required (ex: (MatrixModifiedDT=2014-01-01T00:00:00.000+) )')
  remapKeys(mergeOptions(queryOptions, _queryOptionsDefaults))



module.exports =
  mergeOptions: mergeOptions
  normalizeOptions: normalizeOptions
