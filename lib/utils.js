/*jshint node:true */
/* jshint -W097 */
'use strict';

var urlUtil = require('url');
var replycodes = require('./replycodes');

var replyCodeCheck = function(result, callback) {
    var replyCode = result.RETS.$.ReplyCode;
    var replyText = result.RETS.$.ReplyText;
    // include our const tag if available to associate in error message
    var replyTag = replycodes.tagMap.hasOwnProperty(replyCode) ? "("+replycodes.tagMap[replyCode]+")" : "";
    if (replyCode !== "0") {
        if(typeof callback === "function") {

            var error = new Error("RETS Server returned an error - ReplyCode " + replyTag + ": " + replyCode + " ReplyText: " + replyText);
            error.replyCode = replyCode;
            error.replyText = replyText;

            callback(error);
        }
        return false;
    }

    return true;
};

var xmlParseCheck = function(xml, callback) {
    if (!xml) {
        if(typeof callback === "function")
            callback(new Error("Failed to parse RETS XML: " + xml));
        return false;
    }

    return true;
};

var hex2a = function(hexx) {
    var hex = hexx.toString();//force conversion
    var str = '';
    for (var i = 0; i < hex.length; i += 2)
        str += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
    return str;
};

//Returns a valid url for use with RETS server. If target url just contains a path, fullURL's protocol and host will be utilized.
var getValidUrl = function(targetUrl, fullUrl) {
    var loginUrlObj = urlUtil.parse(fullUrl, true, true);
    var targetUrlObj = urlUtil.parse(targetUrl, true, true);

    if (targetUrlObj.host === loginUrlObj.host)
        return targetUrl;

    var fixedUrlObj = {
        protocol:loginUrlObj.protocol,
        slashes:true,
        host:loginUrlObj.host,
        pathname:targetUrlObj.pathname,
        query:targetUrlObj.query
    };

    return urlUtil.format(fixedUrlObj);
};

module.exports.replyCodeCheck = replyCodeCheck;
module.exports.xmlParseCheck = xmlParseCheck;
module.exports.hex2a = hex2a;
module.exports.getValidUrl = getValidUrl;