### jshint node:true ###
### jshint -W097 ###
'use strict'


# need to make a new object as we merge, as we don't want to modify the user's object
mergeOptions = (options1, options2) ->
  if !options1
    return options2
  result = {}
  
  # copy in options2 first, letting values from options1 overwrite and have priority
  for own key of options2
    result[key] = options2[key]
  for own key of options1
    result[key] = options1[key]
    
  result


# default query parameters
_queryOptionsDefaults =
  queryType: 'DMQL2'
  format: 'COMPACT-DECODED'
  count: 1
  standardNames: 0
  restrictedIndicator: '***'
  limit: 'NONE'


normalizeOptions = (queryOptions) ->
  if !queryOptions
    throw new Error('queryOptions is required.')
  if !queryOptions.searchType
    throw new Error('searchType is required (ex: Property')
  if !queryOptions.class
    throw new Error('class is required (ex: RESI)')
  if !queryOptions.query
    throw new Error('query is required (ex: (MatrixModifiedDT=2014-01-01T00:00:00.000+) )')
  mergeOptions(queryOptions, _queryOptionsDefaults)


module.exports =
  mergeOptions: mergeOptions
  normalizeOptions: normalizeOptions
