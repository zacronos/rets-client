### jshint node:true ###
### jshint -W097 ###
'use strict'

through2 = require('through2')

queryOptionHelpers = require('../utils/queryOptions')
retsHttp = require('../utils/retsHttp')
retsParsing = require('../utils/retsParsing')


###
# Invokes RETS search operation and streams the resulting XML.
#
# @param _queryOptions Search query options.
#    See RETS specification for query options.
#
#    Default values for query params:
#
#       queryType:'DMQL2',
#       format:'COMPACT-DECODED',
#       count:1,
#       standardNames:0,
#       restrictedIndicator:'***',
#       limit:"NONE"
###

searchRets = (queryOptions) -> Promise.try () =>
  finalQueryOptions = queryOptionHelpers.normalizeOptions(queryOptions)
  resultStream = through2()
  httpStream = retsHttp.streamRetsMethod 'search', @retsSession, finalQueryOptions, (err) ->
    httpStream.unpipe(resultStream)
    resultStream.emit('error', err)
  httpStream.pipe(resultStream)


###
#
# Helper that performs a targeted RETS query and streams parsed (or semi-parsed) results
#
# @param searchType Rets resource type (ex: Property)
# @param classType Rets class type (ex: RESI)
# @param query Rets query string. See RETS specification - (ex: MatrixModifiedDT=2014-01-01T00:00:00.000+)
# @param options Search query options (optional).
#    See RETS specification for query options.
# @param rawData flag indicating whether to skip parsing of column and data elements.
#
#    Default values for query params:
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

query = (resourceType, classType, queryString, options={}, rawData=false) ->
  baseOpts =
    searchType: resourceType
    class: classType
    query: queryString
  queryOptions = queryOptionHelpers.mergeOptions(baseOpts, options)

  # make sure queryType and format will use the searchRets defaults
  delete queryOptions.queryType
  delete queryOptions.format
  finalQueryOptions = queryOptionHelpers.normalizeOptions(queryOptions)
  expectRows = "#{finalQueryOptions.count}" != "2"

  context = retsParsing.getStreamParser(null, rawData, expectRows)
  retsHttp.streamRetsMethod('search', @retsSession, finalQueryOptions, context.fail)
  .pipe(context.parser)
  
  context.retsStream


module.exports = (_retsSession) ->
  if !_retsSession
    throw new Error('System data not set; invoke login().')
  retsSession: _retsSession
  query: query
  searchRets: searchRets
