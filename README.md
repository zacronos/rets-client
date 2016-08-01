rets-client
===========
A RETS (Real Estate Transaction Standard) client for Node.js.


## Changes

#### 4.6.0
Added support for `Location: 1` option on `getObject` calls.

#### 4.5.0
Added a new error class for RETS permissions problems on login.

#### 4.4.0
Added a new `parserEncoding` param for `client.search.query()` and `client.search.stream.query()` calls.  UTF-8 is the
default value, so this is to support RETS servers using ISO-8859-1 or some other encoding.

#### 4.3.0
Added support for TimeZoneOffset and Comments in the `metadata.getSystem()` call response.

#### 4.2.0
Improved error handling and error classes.  See the [error documentation](https://github.com/sbruno81/rets-client#errors).

#### 4.1.0
Added client configuration option to use POST instead of GET for all requests, as this seems to work better for some
RETS servers.  See the [Example Usage](https://github.com/sbruno81/rets-client#client-configuration).

#### 4.0.0 and earlier
See [the changelog](./blob/master/CHANGELOG.md) for earlier changes.


## Implementation Notes

This interface uses promises, and an optional stream-based interface for better performance with large search results.
Future development will include an optional stream-based interface for object downloads, and an improved API for the
non-streaming object methods.

This library is written primarily in CoffeeScript, but may be used just as easily in a Node app using Javascript or
CoffeeScript.  Promises in this module are provided by [Bluebird](https://github.com/petkaantonov/bluebird).

The original module was developed against a server running RETS v1.7.2, so there may be incompatibilities with other
versions.  However, we want this library to work against any RETS servers that are in current use, so issue tickets
describing problems or (even better) pull requests that fix interactions with servers running other versions of RETS
are welcomed.

For more information about what all the parameters and return values and such mean, you might want to look at the
[RETS Specifications](http://www.reso.org/specifications)


## Contributions
Issue tickets and pull requests are welcome.  Pull requests must be backward-compatible to be considered, and ideally
should match existing code style.

#### TODO
- create unit tests -- specifically ones that run off example RETS data rather than requiring access to a real RETS server


## Example Usage

##### Client Configuration
```javascript
    //create rets-client
    var clientSettings = {
        loginUrl: retsLoginUrl,
        username: retsUser,
        password: retsPassword,
        version: 'RETS/1.7.2',
        userAgent: 'RETS node-client/4.x',
        method: 'GET'  // this is the default, or for some servers you may want 'POST'
    };
...
```

##### Client Configuration with UA Authorization
```javascript
    //create rets-client
    var clientSettings = {
        version: 'RETS/1.7.2',
        userAgent: userAgent,
        userAgentPassword: userAgentPassword,
        sessionId: sessionId
    };
...
```

##### Output helper used in many examples below

```javascript
  function outputFields(obj, opts) {
    if (!opts) opts = {};
    
    var excludeFields;
    var loopFields;
    if (opts.exclude) {
      excludeFields = opts.exclude;
      loopFields = Object.keys(obj);
    } else if (opts.fields) {
      loopFields = opts.fields;
      excludeFields = [];
    } else {
      loopFields = Object.keys(obj);
      excludeFields = [];
    }
    for (var i=0; i<loopFields.length; i++) {
      if (excludeFields.indexOf(loopFields[i]) != -1) {
        continue;
      }
      if (typeof(obj[loopFields[i]]) == 'object') {
        console.log("    "+loopFields[i]+": "+JSON.stringify(obj[loopFields[i]]));
      } else {
        console.log("    "+loopFields[i]+": "+obj[loopFields[i]]);
      }
    }
    console.log("");
  };
```

#### Example rets-client code
```javascript
  var rets = require('rets-client');
  var fs = require('fs');
  var photoSourceId = '12345'; // <--- dummy example ID!  this will usually be a MLS number / listing id
  
  // establish connection to RETS server which auto-logs out when we're done
  rets.getAutoLogoutClient(clientSettings, function (client) {
    console.log("===================================");
    console.log("========  System Metadata  ========");
    console.log("===================================");
    outputFields(client.systemData);
    
    //get resources metadata
    return client.metadata.getResources()
      .then(function (data) {
        console.log("======================================");
        console.log("========  Resources Metadata  ========");
        console.log("======================================");
        outputFields(data.results[0].info);
        for (var dataItem = 0; dataItem < data.results[0].metadata.length; dataItem++) {
          console.log("-------- Resource " + dataItem + " --------");
          outputFields(data.results[0].metadata[dataItem], {fields: ['ResourceID', 'StandardName', 'VisibleName', 'ObjectVersion']});
        }
      }).then(function () {
      
        //get class metadata
        return client.metadata.getClass("Property");
      }).then(function (data) {
        console.log("===========================================================");
        console.log("========  Class Metadata (from Property Resource)  ========");
        console.log("===========================================================");
        outputFields(data.results[0].info);
        for (var classItem = 0; classItem < data.results[0].metadata.length; classItem++) {
          console.log("-------- Table " + classItem + " --------");
          outputFields(data.results[0].metadata[classItem], {fields: ['ClassName', 'StandardName', 'VisibleName', 'TableVersion']});
        }
      }).then(function () {
      
        //get field data for open houses
        return client.metadata.getTable("Property", "RESIDENTIAL");
      }).then(function (data) {
        console.log("==============================================");
        console.log("========  Residential Table Metadata  ========");
        console.log("===============================================");
        outputFields(data.results[0].info);
        for (var tableItem = 0; tableItem < data.results[0].metadata.length; tableItem++) {
          console.log("-------- Field " + tableItem + " --------");
          outputFields(data.results[0].metadata[tableItem], {fields: ['MetadataEntryID', 'SystemName', 'ShortName', 'LongName', 'DataType']});
        }
        return data.results[0].metadata
      }).then(function (fieldsData) {
        var plucked = [];
        for (var fieldItem = 0; fieldItem < fieldsData.length; fieldItem++) {
          plucked.push(fieldsData[fieldItem].SystemName);
        }
        return plucked;
      }).then(function (fields) {
      
        //perform a query using DMQL2 -- pass resource, class, and query, and options
        return client.search.query("Property", "RESIDENTIAL", "(RecordModDate=2016-06-20+),(ActiveYN=1)", {limit:100, offset:10})
        .then(function (searchData) {
          console.log("=============================================");
          console.log("========  Residential Query Results  ========");
          console.log("=============================================");
          outputFields(searchData, {exclude: ['results']});
          //iterate through search results
          for (var dataItem = 0; dataItem < searchData.results.length; dataItem++) {
            console.log("-------- Result " + dataItem + " --------");
            outputFields(searchData.results[dataItem], {fields: fields});
          }
          if (searchData.maxRowsExceeded) {
            console.log("-------- More rows available!");
          }
        });
      }).then(function () {
      
        // get photos
        return client.objects.getAllObjects("Property", "LargePhoto", photoSourceId, {alwaysGroupObjects: true, ObjectData: '*'})
      }).then(function (photoResults) {
        console.log("=================================");
        console.log("========  Photo Results  ========");
        console.log("=================================");
        for (var i = 0; i < photoResults.objects.length; i++) {
          if (photoResults.objects[i].error) {
            console.log("Photo " + (i + 1) + " had an error: " + photoResults.objects[i].error);
          } else {
            console.log("Photo " + (i + 1) + ":");
            outputFields(photoResults.objects[i].headerInfo);
            fs.writeFileSync(
              "/tmp/photo" + (i + 1) + "." + photoResults.objects[i].headerInfo.contentType.match(/\w+\/(\w+)/i)[1],
              photoResults.objects[i].data);
          }
          console.log("---------------------------------");
        }
      });
      
  }).catch(function (errorInfo) {
    var error = errorInfo.error || errorInfo;
    console.log("ERROR: issue encountered: "+(error.stack||error));
  });
```

#### Simple streaming example
```javascript
  var rets = require('rets-client');
  var through2 = require('through2');
  var Promise = require('bluebird');
  
  // this function doesn't do much, it's just a placeholder for whatever you want to do with the results 
  function doAsyncProcessing(row, index, callback) {
    console.log("-------- Result " + index + " --------");
    outputFields(row);
    // must be sure callback is called when this is done
    callback();
  }
  
  // establish connection to RETS server which auto-logs out when we're done
  rets.getAutoLogoutClient(clientSettings, function (client) {
    // in order to have the auto-logout function work properly, we need to make a promise that either rejects or
    // resolves only once we're done processing the stream
    return new Promise(function (resolve, reject) {
      console.log("====================================");
      console.log("========  Streamed Results  ========");
      console.log("====================================");
      var count = 0;
      var retsStream = client.search.stream.query("OpenHouse", "OPENHOUSE", "(OpenHouseType=PUBLIC),(ActiveYN=1)", {limit:100, offset:10});
      var processorStream = through2.obj(function (event, encoding, callback) {
        switch (event.type) {
          case 'data':
            // event.payload is an object representing a single row of results
            // make sure callback is called only when all processing is complete
            count++;
            doAsyncProcessing(event.payload, count, callback);
            break;
          case 'done':
            // event.payload is an object containing a count of rows actually received, plus some other things
            // now we can resolve the auto-logout promise
            resolve(event.payload.rowsReceived);
            callback();
            break;
          case 'error':
            // event.payload is an Error object
            console.log('Error streaming RETS results: '+event.payload);
            retsStream.unpipe(processorStream);
            processorStream.end();
            // we need to reject the auto-logout promise
            reject(event.payload);
            callback();
            break;
          default:
            // ignore other events
            callback();
        }
      });
      retsStream.pipe(processorStream);
    });
  });
```

#### Photo streaming example
```javascript
  var rets = require('rets-client');
  // establish connection to RETS server which auto-logs out when we're done
  rets.getAutoLogoutClient(clientSettings, function (client) {
    // getObjects will accept a single string, an array of strings, or an object as shown below
    var photoIds = {
      '11111': [1,3],  // get photos #1 and #3 for listingId 11111
      '22222': '*',    // get all photos for listingId 22222
      '33333': '0'     // get 'preferred' photo for listingId 33333
    };
    return client.objects.stream.getObjects('Property', 'Photo', photoIds, {alwaysGroupObjects: true, ObjectData: '*'})
    .then(function (photoStream) {
      return new Promise(function (resolve, reject) {
        var i=0;
        photoStream.objectStream.on('data', function (photoEvent) {
          i++;
          if (photoEvent.error) {
            console.log("Photo " + i + " had an error: " + photoEvent.error);
          } else {
            console.log("Photo " + (i + 1) + ":");
            outputFields(photoEvent.headerInfo);
            fileStream = fs.createWriteStream(
              "/tmp/photo" + i + "." + photoEvent.headerInfo.contentType.match(/\w+\/(\w+)/i)[1]);
            photoEvent.dataStream.pipe(fileStream);
          }
        });
        photoStream.objectStream.on('end', function () {
          resolve();
        });
      });
    });
  });
```

##### Errors
There are 6 error classes exposed by this module:
* `RetsError`: A parent class for all the errors below, to make it more convenient to catch errors from this library.
I've made somewhat of an effort to catch any errors thrown by dependencies of this library and re-throw them as instances
of RetsError, so that any error generated by a call to this library can be detected the same way; if you find an error
coming through that didn't get this treatment, please open a ticket (or better, a PR!) to let me know.
* `RetsParamError`: Used when a required function parameter is missing or has an invalid value
* `RetsServerError`: Used when the HTTP response indicates an error, such as a "401 Unauthorized" response
* `RetsReplyError`: Used when the HTTP response is valid, but the XML RETS response indicates an error
* `RetsProcessingError`: Used when a problem is encountered processing the response from the RETS server
* `RetsPermissionError`: Used when RETS login is successful, but the account does not have the full permissions expected

##### Debugging
You can turn on all debug logging by adding `rets-client:*` to your `DEBUG` environment variable, as per the
[debug module](https://github.com/visionmedia/debug).  Sub-loggers available:
* `rets-client:main`: basic logging of RETS call options and errors
* `rets-client:request`: logging of HTTP request/response headers and other related info, with output almost identical
to that provided by the [request-debug module](https://github.com/request/request-debug).

If you want access to the request debugging data directly, you can use the `requestDebugFunction` client setting.  This
function will be set up as a debug handler as per the [request-debug module](https://github.com/request/request-debug).

In order to get either `rets-client:request` logging, or to use `requestDebugFunction`, you will need to ensure
dev dependencies (in particular, request-debug) are installed for rets-client.  The easiest way to do this is to first
change directory to the location of rets-client (e.g. `cd ./node_modules/rets-client`), and then run `npm install`.
