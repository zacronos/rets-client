var fs = require('fs');
var rets = require('../index');

var outputFields = function(obj, fields) {
  for (var i=0; i<fields.length; i++) {
    console.log(fields[i]+": "+obj[fields[i]]);
  }
  console.log("");
};

module.exports = function(settings, photoId) {
  // establish connection to RETS server which auto-logs out when we're done
  rets.getAutoLogoutClient(settings, function (client) {
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
        return data.Fields;
      }).then(function (fieldsData) {
        var plucked = [];
        for (var fieldItem = 0; fieldItem < fieldsData.length; fieldItem++) {
          plucked.push(fieldsData[fieldItem].SystemName);
        }
        return plucked;
      }).then(function (fields) {
        //perform a query using DQML2 -- pass resource, class, and query, and options
        return client.search.query("OpenHouse", "OPENHOUSE", "(OpenHouseType=PUBLIC),(ActiveYN=1)", {limit: 10})
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
};
