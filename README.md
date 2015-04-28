rets-promise
============
A RETS (Real Estate Transaction Standard) client for Node.js with a clean, promise-based interface.

Forked originally from [rets-client](https://github.com/sbruno81/rets-client), with the user-facing API rewritten
with breaking changes to use a Promise-based interface.  Promises in this module are provided by
[Bluebird](https://github.com/petkaantonov/bluebird).  This library contains some CoffeeScript, but may be used just
as easily in a Node app using Javascript or CoffeeScript.

The original module was developed against a server running RETS v1.7.2, so there may be incompatibilities with other
versions.  However, the developers at RealtyMaps want this library to work against any RETS server versions that are
in current use, so issue tickets describing problems or (even better) pull requests that fix interactions
with other RETS versions are welcomed.

[RETS Specifications](http://www.reso.org/specifications)

## Contributions
Issue tickets and pull requests are welcome.  Unless a breaking refactor is necessary, the `auth`, `metadata`,
`multipart`, `object`, `search`, and `utils` files in lib/ should be kept JavaScript in order to facilitate PRs
to/from other `rets-client` forks.

Ideally, pull requests should include tests and match existing code style.

#### TODO
- Update dependency versions
- move off https://github.com/Gozala/crypto to use node-native crypto module instead
- add support for UA password as described here: https://github.com/sbruno81/rets-client/issues/1
-- might already be handled
- make sure listeners are deregistering so app will exit after logout


## Example RETS Session
```javascript
  var rets = require('rets-promise');
  // establish connection to RETS server which auto-logs out when we're done
  rets.getAutoLogoutClient(settings, function (client) {
    //get resources metadata
    return client.metadata.getResources()
      .then(function (data) {
        console.log("======== Resources Metadata ========");
        console.log(data.Version);
        console.log(data.Date);
        for (var dataItem = 0; dataItem < data.Resources.length; dataItem++) {
          console.log(data.Resources[dataItem].ResourceID);
          console.log(data.Resources[dataItem].StandardName);
          console.log(data.Resources[dataItem].VisibleName);
          console.log(data.Resources[dataItem].ObjectVersion);
        }
      }).then(function () {
        //get class metadata
        return client.metadata.getClass("Property");
      }).then(function (data) {
        console.log("======== Property Class Metadata ========");
        console.log(data.Version);
        console.log(data.Date);
        console.log(data.Resource);
        for (var classItem = 0; classItem < data.Classes.length; classItem++) {
          console.log(data.Classes[classItem].ClassName);
          console.log(data.Classes[classItem].StandardName);
          console.log(data.Classes[classItem].VisibleName);
          console.log(data.Classes[classItem].TableVersion);
        }
      }).then(function () {
        //get field data for open houses
        return client.metadata.getTable("OpenHouse", "OPENHOUSE");
      }).then(function (data) {
        console.log("======== OpenHouse Table Metadata ========");
        console.log(data.Version);
        console.log(data.Date);
        console.log(data.Resource);
        console.log(data.Class);

        for (var tableItem = 0; tableItem < data.Fields.length; tableItem++) {
          console.log(data.Fields[tableItem].MetadataEntryID);
          console.log(data.Fields[tableItem].SystemName);
          console.log(data.Fields[tableItem].ShortName);
          console.log(data.Fields[tableItem].LongName);
          console.log(data.Fields[tableItem].DataType);
        }

        return data.Fields
      }).then(function (fields) {
        //perform a query using DQML -- pass resource, class, and query
        client.search.query("OpenHouse", "OPENHOUSE", "(OpenHouseType=PUBLIC),(ActiveYN=1)")
          .then(function (results) {
            console.log("======== OpenHouse Query Results ========");
            //iterate through search results
            for (var dataItem = 0; dataItem < results.length; dataItem++) {
              console.log("-------- Open House "+dataItem+" --------");
              for (var fieldItem = 0; fieldItem < fields.length; fieldItem++) {
                var systemStr = fields[fieldItem].SystemName;
                console.log(systemStr + " : " + results[dataItem][systemStr]);
              }

              console.log("\n");
            }
          });
      }).then(function () {
        // get photos
        return client.objects.getPhotos("Property", "LargePhoto", photoId)
      }).then(function (photoList) {
        console.log("======== Photo Results ========");
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
