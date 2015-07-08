/*jshint node:true */
/* jshint -W097 */
'use strict';

var logger = require('winston'),
    streamBuffers = require("stream-buffers"),
    multipart = require("./multipart.js");

/**
 * Retrieves RETS object data.
 *
 * @param resourceType Rets resource type (ex: Property)
 * @param objectType Rets object type (ex: LargePhoto)
 * @param objectId Object identifier
 * @param callback(error, contentType, data) (optional)
 */
var getObject = function(resourceType, objectType, objectId, callback) {
    logger.debug("RETS method getObject");

    if (!objectType || !objectId || !resourceType) {
        if(typeof callback === "function")
            callback(new Error("All params are required: objectType, objectId, resourceType"));

        return;
    }

    if (!this.retsSession) {
        if(typeof callback === "function")
            callback(new Error("System data not set; invoke login first."));

        return;
    }

    var options = {
        qs:{
            Type:objectType,
            Id:objectId,
            Resource:resourceType
        }
    };

    //prepare stream buffer for object data
    var writableStreamBuffer = new streamBuffers.WritableStreamBuffer({
        initialSize: (100 * 1024),      // start as 100 kilobytes.
        incrementAmount: (10 * 1024)    // grow by 10 kilobytes each time buffer overflows.
    });
    var req = this.retsSession(options);

    //pipe object data to stream buffer
    req.pipe(writableStreamBuffer);
    req.on("error", function(err) {
        if(typeof callback === "function") {
            callback(err);
        }
    });
    var contentType = null;
    req.on("response", function(_response){
        contentType = _response.headers["content-type"];
    });
    req.on("end", function() {
        if(typeof callback === "function") {
            callback(null, {contentType:contentType, data:writableStreamBuffer.getContents()});
        }
    });

};


/**
 * Helper that retrieves a list of photo objects.
 *
 * @param resourceType Rets resource type (ex: Property)
 * @param photoType Photo object type, based on getObjects meta call (ex: LargePhoto, Photo)
 * @param matrixId Photo matrix identifier.
 * @param callback(error, dataList) (optional)
 *
 *      Each item in data list is an object with the following data elements:
 *
 *       {
 *          buffer:<data buffer>,
 *          mime:<data buffer mime type>,
 *          description:<data description>,
 *          contentDescription:<data content description>,
 *          contentId:<content identifier>,
 *          objectId:<object identifier>
 *        }
 *
 */
var getPhotos = function(resourceType, photoType, matrixId, callback) {
    this.getObject(resourceType, photoType, matrixId+":*", function(error, result) {
        var multipartBoundary = result.contentType.match(/boundary=(?:"([^"]+)"|([^;]+))/i)[1];

        multipart.parseMultipart(new Buffer(result.data), multipartBoundary, function(error, dataList) {
            callback(error, dataList);
        });
    });
};

module.exports = function(_retsSession) {
    return {
        retsSession: _retsSession,
        getObject: getObject,
        getPhotos: getPhotos
    };
};

