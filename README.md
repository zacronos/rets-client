rets-client
===========
A RETS (Real Estate Transaction Standard) client for Node.js.  This README documents the version 2.x branch, which is
currently under unstable development.  Code written for version 1.x of rets-client will not work with 2.x.  A
Promise-based interface is provided for now, and later an optional stream-based interface will also be available.
Promises in this module are provided by [Bluebird](https://github.com/petkaantonov/bluebird).

This library contains some CoffeeScript, but may be used just as easily in a Node app using Javascript or CoffeeScript.

The original module was developed against a server running RETS v1.7.2, so there may be incompatibilities with other
versions.  However, we want this library to work against any RETS servers that are in current use, so issue tickets
describing problems or (even better) pull requests that fix interactions with servers running other versions of RETS
are welcomed.

[RETS Specifications](http://www.reso.org/specifications)

## Contributions
Issue tickets and pull requests are welcome.  Ideally, pull requests should include tests and match existing code style.
Breaking changes are currently acceptable on the 2.0.0-unstable branch; once this branch is merged to master, only
backward-compatible PRs will be accepted.

#### TODO
- create optional streaming interface 
- update dependency versions
- create unit tests -- specifically ones that run off example RETS data rather than requiring access to a real RETS server


## Example Usage

##### Client Configuration
```javascript
    //create rets-client
    var clientSettings = {
        loginUrl:retsLoginUrl,
        username:retsUser,
        password:retsPassword,
        version:'RETS/1.7.2',
        userAgent:'RETS node-client/1.0'
    };
...
```    
##### Client Configuration with UA Authorization
```javascript
    //create rets-client
    var clientSettings = {
        version:'RETS/1.7.2',
        userAgent:userAgent,
        userAgentPassword:userAgentPassword,
        sessionId:sessionId
    };
...
```

#### RETS Session
```javascript
  var rets = require('rets-promise');
  var outputFields = function(obj, fields) {
    for (var i=0; i<fields.length; i++) {
      console.log(fields[i]+": "+obj[fields[i]]);
    }
    console.log("");
  };
  // establish connection to RETS server which auto-logs out when we're done
  rets.getAutoLogoutClient(clientSettings, function (client) {
    //get resources metadata
    return client.metadata.getResources()
      .then(function (data) {
        console.log("======================================");
        console.log("========  Resources Metadata  ========");
        console.log("======================================");
        outputFields(data, ['Version', 'Date']);
        for (var dataItem = 0; dataItem < data.Resources.length; dataItem++) {
          console.log("-------- Resource " + dataItem + " --------");
          outputFields(data.Resources[dataItem], ['ResourceID', 'StandardName', 'VisibleName', 'ObjectVersion']);
        }
      }).then(function () {
        //get class metadata
        return client.metadata.getClass("Property");
      }).then(function (data) {
        console.log("===========================================================");
        console.log("========  Class Metadata (from Property Resource)  ========");
        console.log("===========================================================");
        outputFields(data, ['Version', 'Date', 'Resource']);
        for (var classItem = 0; classItem < data.Classes.length; classItem++) {
          console.log("-------- Table " + classItem + " --------");
          outputFields(data.Classes[classItem], ['ClassName', 'StandardName', 'VisibleName', 'TableVersion']);
        }
      }).then(function () {
        //get field data for open houses
        return client.metadata.getTable("OpenHouse", "OPENHOUSE");
      }).then(function (data) {
        console.log("=============================================");
        console.log("========  OpenHouse Table Metadata  ========");
        console.log("=============================================");
        outputFields(data, ['Version', 'Date', 'Resource', 'Class']);
        for (var tableItem = 0; tableItem < data.Fields.length; tableItem++) {
          console.log("-------- Field " + tableItem + " --------");
          outputFields(data.Fields[tableItem], ['MetadataEntryID', 'SystemName', 'ShortName', 'LongName', 'DataType']);
        }
        return data.Fields
      }).then(function (fieldsData) {
        var plucked = [];
        for (var fieldItem = 0; fieldItem < fieldsData.length; fieldItem++) {
          plucked.push(fieldsData[fieldItem].SystemName);
        }
        return plucked;
      }).then(function (fields) {
        //perform a query using DQML2 -- pass resource, class, and query, and options
        return client.search.queryWithOpts("OpenHouse", "OPENHOUSE", "(OpenHouseType=PUBLIC),(ActiveYN=1)", {limit:100, offset:1})
        .then(function (results) {
          console.log("===========================================");
          console.log("========  OpenHouse Query Results  ========");
          console.log("===========================================");
          console.log("");
          //iterate through search results
          for (var dataItem = 0; dataItem < results.length; dataItem++) {
            console.log("-------- Result " + dataItem + " --------");
            outputFields(results[dataItem], fields);
          }
        });
      }).then(function () {
        // get photos
        return client.objects.getPhotos("Property", "LargePhoto", photoId)
      }).then(function (photoList) {
        console.log("=================================");
        console.log("========  Photo Results  ========");
        console.log("=================================");
        for (var i = 0; i < photoList.length; i++) {
          console.log("Photo " + (i + 1) + " MIME type: " + photoList[i].mime);
          fs.writeFileSync(
            "/tmp/photo" + (i + 1) + "." + photoList[i].mime.match(/\w+\/(\w+)/i)[1],
            photoList[i].buffer
          );
        }
      });
  }).catch(function (error) {
    console.log("ERROR: issue encountered: "+(error.stack||error));
  });
```
