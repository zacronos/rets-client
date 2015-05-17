/*jshint node:true */
/* jshint -W097 */
'use strict';

var logger = require('winston'),
    utils = require('./utils.js'),
    xmlParser = require('xml2js').parseString;

var retsSession;

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
            if (callback)
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

        if (callback)
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
        if (callback)
            callback(new Error("_queryOptions is required."));

        return;
    }

    if (!_queryOptions.searchType) {
        if (callback)
            callback(new Error("_queryOptions.searchType field is required."));

        return;
    }

    if (!_queryOptions.class) {
        if (callback)
            callback(new Error("_queryOptions.class field is required."));

        return;
    }

    if (!_queryOptions.query) {
        if (callback)
            callback(new Error("_queryOptions.query field is required."));

        return;
    }

    if (!retsSession) {
        if (callback)
            callback(new Error("System data not set; invoke login first."));

        return;
    }

    mergeInto(queryOptions, _queryOptions);

    var options = {
        qs:queryOptions
    };

    retsSession(options, function(error, response, body) {

        var isErr = error || false;

        if (!isErr && response.statusCode != 200)
        {
            isErr = true;
            error = new Error("RETS method search returned unexpected status code: " + response.statusCode);
        }

        if (isErr) {
            logger.debug("Search Error:\n\n" + JSON.stringify(error));
            if (callback)
                callback(error);

            return;
        }

        if (callback) {
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
 * @param callback(error, data) (optional)
 * @param _limit (optional) Limits the number of records returned.
 * @param _offset (optional) Results offset.
 * @param _count (optional) Controls whether the server’s response includes a count.
 */
var query = function(resourceType, classType, queryString, callback, _limit, _offset, _count) {

    if (!resourceType) {
        if (callback)
            callback(new Error("resourceType is required: (ex: Property)"));

        return;
    }

    if (!classType) {
        if (callback)
            callback(new Error("classType is required: (ex: RESI)"));

        return;
    }

    if (!queryString) {
        if (callback)
            callback(new Error("queryString is required: (ex: (MatrixModifiedDT=2014-01-01T00:00:00.000+))"));

        return;
    }

    var limit = "NONE";
    if (_limit) {
        limit = "" + _limit;
    }

    var offset = "1";
    if (_offset) {
        offset = "" + _offset;
    }

    var count = "1";
    if (_count) {
        count = "" + _count;
    }

    var queryOpts = {
        searchType:resourceType,
        class:classType,
        query:queryString,
        limit:limit,
        offset:offset,
        count:count
    };

    searchRets(queryOpts, function(error, data) {
        parseCompactDecoded(data, function(error, data) {
            if (callback) {
                callback(error, data);
            }
        });
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
var queryWithOpts = function(resourceType, classType, queryString, _options, callback) {

    if (!resourceType) {
        if (callback)
            callback(new Error("resourceType is required: (ex: Property)"));

        return;
    }

    if (!classType) {
        if (callback)
            callback(new Error("classType is required: (ex: RESI)"));

        return;
    }

    if (!queryString) {
        if (callback)
            callback(new Error("queryString is required: (ex: (MatrixModifiedDT=2014-01-01T00:00:00.000+))"));

        return;
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

    searchRets(queryOpts, function(error, data) {
        parseCompactDecoded(data, function(error, data) {
            if (callback) {
                callback(error, data);
            }
        });
    });
};

module.exports = function(_retsSession) {
    retsSession = _retsSession;

    return {
        searchRets:searchRets,
        query: query,
        queryWithOpts:queryWithOpts
    };
};

