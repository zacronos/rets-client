/*jshint node:true */
/* jshint -W097 */
'use strict';

var logger = require('winston'),
    xmlParser = require('xml2js').parseString;

/**
 * Executes RETS login routine.
 * @param callback(error, client)
 */
var login = function(retsSession, callback) {

    logger.debug("Rets method login");

    retsSession({}, function(error, response, body) {
        var isErr = error || false;

        if (!isErr && response.statusCode != 200)
        {
            isErr = true;
            var errMsg = "RETS method login returned unexpected HTTP status code: " + response.statusCode;
            error = new Error(errMsg);
            error.replyCode = response.statusCode;
            error.replyText = errMsg;
        }

        if (isErr) {
            if(typeof callback === "function")
                callback(error);

            return;
        }

        var retsXml;
        xmlParser(body, function(err, result) {

            if (!result || !result.RETS) {
                if(typeof callback === "function")
                    callback(new Error("Unexpected results. Please check the RETS URL"));
                return;
            }

            retsXml = result.RETS["RETS-RESPONSE"];
            var keyVals = retsXml[0].split("\r\n");

            var systemData = {};

            for(var i = 0; i < keyVals.length; i++)
            {
                var keyValSplit = keyVals[i].split("=");
                if (keyValSplit.length > 1) {
                    systemData[keyValSplit[0]] = keyValSplit[1];
                }
            }

            systemData.retsVersion = response.headers["rets-version"];
            systemData.retsServer = response.headers.server;

            if(typeof callback === "function")
                callback(error, systemData);
        });
    });
};

/**
 * Logouts RETS user
 * @param callback(error)
 *
 * @event logout.success Logout was successful
 * @event logout.failure(error) Logout failure
 *
 */
var logout = function(retsSession, callback) {

    logger.debug("RETS method logout");

    retsSession({}, function(error, response, body) {

        var isErr = error || false;

        if (!isErr && response.statusCode != 200)
        {
            isErr = true;

            var errMsg = "RETS method logout returned unexpected status code: " + response.statusCode;
            error = new Error(errMsg);
            error.replyCode = response.statusCode;
            error.replyText = errMsg;
        }

        if (isErr) {
            if(typeof callback === "function")
                callback(error);

            return;
        }

        logger.debug("Logout success");

        if(typeof callback === "function")
            callback(error, true);
    });
};

module.exports.login = login;
module.exports.logout = logout;
