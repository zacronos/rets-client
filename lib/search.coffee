### jshint node:true ###
### jshint -W097 ###
'use strict'

logger = require('winston')
Promise = require('bluebird')

utils = require('./utils')


setDefaults = (options, defaults) ->
  if !options
    return options
  result = {}
  for own key of options
    result[key] = options[key]
  for own key of defaults when key not of result
    result[key] = defaults[key]
  result


#default query parameters
queryOptionsDefaults =
  queryType: 'DMQL2'
  format: 'COMPACT-DECODED'
  count: 1
  standardNames: 0
  restrictedIndicator: '***'
  limit: 'NONE'

###
# Invokes RETS search operation.
#
# @param _queryOptions Search query options.
#    See RETS specification for query options.
#
#    Default values query params:
#
#       queryType:'DMQL2',
#       format:'COMPACT-DECODED',
#       count:1,
#       standardNames:0,
#       restrictedIndicator:'***',
#       limit:"NONE"
###

searchRets = (queryOptions) -> Promise.try () =>
  logger.debug 'RETS method search'
  if !queryOptions
    throw new Error('queryOptions is required.')
  if !queryOptions.searchType
    throw new Error('searchType is required (ex: Property')
  if !queryOptions.class
    throw new Error('class is required (ex: RESI)')
  if !queryOptions.query
    throw new Error('query is required (ex: (MatrixModifiedDT=2014-01-01T00:00:00.000+) )')
  finalQueryOptions = setDefaults(queryOptions, queryOptionsDefaults)
  utils.callRetsMethod('search', @retsSession, finalQueryOptions)
  .then (result) ->
    result.body

###
#
# Helper that performs a targeted RETS query and parses results.
#
# @param searchType Rets resource type (ex: Property)
# @param classType Rets class type (ex: RESI)
# @param query Rets query string. See RETS specification - (ex: MatrixModifiedDT=2014-01-01T00:00:00.000+)
# @param _options Search query options (optional).
#    See RETS specification for query options.
#
#    Default values query params:
#
#       queryType:'DMQL2',
#       format:'COMPACT-DECODED',
#       count:1,
#       standardNames:0,
#       restrictedIndicator:'***',
#       limit:"NONE"
#
#       Please note that queryType and format are immutable.
###

query = (resourceType, classType, queryString, options) -> Promise.try () =>
  baseOpts =
    searchType: resourceType
    class: classType
    query: queryString
  finalQueryOptions = setDefaults(baseOpts, options)
  # make sure queryType and format will use the searchRets defaults
  delete finalQueryOptions.queryType
  delete finalQueryOptions.format
  @searchRets(finalQueryOptions)
  .then utils.parseCompact


module.exports = (_retsSession) ->
  if !_retsSession
    throw new Error('System data not set; invoke login().')
  retsSession: Promise.promisify(_retsSession)
  searchRets: searchRets
  query: query
