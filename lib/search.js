/*jshint node:true */
/* jshint -W097 */
'use strict';

var logger = require('winston'),
    utils = require('./utils.js'),
    xmlParser = require('xml2js').parseString;

function mergeInto(o1, o2) {
    if (o1 === null || o2 === null)
        return o1;

    for (var key in o2)
        if (o2.hasOwnProperty(key))
            o1[key] = o2[key];

    return o1;
}

var parseCompactDecoded = function(resp, callback) {

    var columnsXml, dataXml, delimiter;
    xmlParser(resp, function(error, result) {

        if (!utils.replyCodeCheck(result, callback)) return;

        columnsXml = result.RETS.COLUMNS;

        if(!utils.xmlParseCheck(columnsXml, callback)) return;

        dataXml = result.RETS.DATA;

        if(!utils.xmlParseCheck(dataXml, callback)) return;
        delimiter = utils.hex2a(result.RETS.DELIMITER[0].$.value);

        if (delimiter === undefined)
        {
            if(typeof callback === "function")
                callback(new Error("No specified delimiter."));

            return;
        }

        var columns = columnsXml.toString().split(delimiter);
        var searchResults = [];
        for(var i = 0; i < dataXml.length; i++) {
            var data = dataXml[i].toString().split(delimiter);

            var model = {};
            for(var j = 1; j < columns.length-1; j++) {
                model[columns[j]] = data[j];
            }

            searchResults.push(model);
        }

        if(typeof callback === "function")
            callback(error, searchResults);
    });
};

//default query parameters
var queryOptions = {
    queryType:'DMQL2',
    format:'COMPACT-DECODED',
    count:1,
    standardNames:0,
    restrictedIndicator:'***',
    limit:"NONE"
};

/**
 * Invokes RETS search operation.
 *
 * @param _queryOptions Search query options.
 *        See RETS specification for query options.
 *
 *        Default values query params:
 *
 *           queryType:'DMQL2',
 *           format:'COMPACT-DECODED',
 *           count:1,
 *           standardNames:0,
 *           restrictedIndicator:'***',
 *           limit:"NONE"
 *
 * @param callback(error, data) (optional)
 */
var searchRets = function(_queryOptions, callback) {

    logger.debug("RETS method search");


    if (!_queryOptions) {
        if(typeof callback === "function")
            callback(new Error("_queryOptions is required."));

        return;
    }

    if (!_queryOptions.searchType) {
        if(typeof callback === "function")
            callback(new Error("_queryOptions.searchType field is required."));

        return;
    }

    if (!_queryOptions.class) {
        if(typeof callback === "function")
            callback(new Error("_queryOptions.class field is required."));

        return;
    }

    if (!_queryOptions.query) {
        if(typeof callback === "function")
            callback(new Error("_queryOptions.query field is required."));

        return;
    }

    if (!this.retsSession) {
        if(typeof callback === "function")
            callback(new Error("System data not set; invoke login first."));

        return;
    }

    mergeInto(queryOptions, _queryOptions);

    var options = {
        qs:queryOptions
    };

    this.retsSession(options, function(error, response, body) {

        var isErr = error || false;

        if (!isErr && response.statusCode != 200)
        {
            isErr = true;
            error = new Error("RETS method search returned unexpected status code: " + response.statusCode);
        }

        if (isErr) {
            logger.debug("Search Error:\n\n" + JSON.stringify(error));
            if(typeof callback === "function")
                callback(error);

            return;
        }

        if(typeof callback === "function") {
            callback(error, body);
        }
    });
};

/**
 *
 * Helper that performs a targeted RETS query and parses results.
 *
 * @param resourceType Rets resource type (ex: Property)
 * @param classType  Rets class type (ex: RESI)
 * @param queryString Rets query string. See RETS specification - (ex: MatrixModifiedDT=2014-01-01T00:00:00.000+)
 * @param _options Search query options (optional).
 *        See RETS specification for query options.
 *
 *        Default values query params:
 *
 *           queryType:'DMQL2',
 *           format:'COMPACT-DECODED',
 *           count:1,
 *           standardNames:0,
 *           restrictedIndicator:'***',
 *           limit:"NONE"
 *
 *           Please note that queryType and format are immutable.
 * @param callback(error, data) (optional)
 */
var query = function(resourceType, classType, queryString, _options, callback) {

    if (!resourceType) {
        if(typeof callback === "function")
            callback(new Error("resourceType is required: (ex: Property)"));

        return;
    }

    if (!classType) {
        if(typeof callback === "function")
            callback(new Error("classType is required: (ex: RESI)"));

        return;
    }

    if (!queryString) {
        if(typeof callback === "function")
            callback(new Error("queryString is required: (ex: (MatrixModifiedDT=2014-01-01T00:00:00.000+))"));

        return;
    }
  
    if (typeof(_options) == 'function') {
      callback = _options;
      _options = undefined;
    }

    var queryOpts = {
        searchType:resourceType,
        class:classType,
        query:queryString
    };

    if (_options) {
        mergeInto(queryOpts, _options);
    }

    queryOpts.queryType = 'DMQL2';
    queryOpts.format = 'COMPACT-DECODED';

    searchRets(queryOpts, function(error, rawData) {
        parseCompactDecoded(rawData, function(error, parsedData) {
            if(typeof callback === "function") {
                callback(error, parsedData);
            }
        });
    });
};

module.exports = function(_retsSession) {

    return {
        retsSession: _retsSession,
        searchRets:searchRets,
        query: query
    };
};

