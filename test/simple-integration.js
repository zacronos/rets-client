var fs = require('fs');
var rets = require('../index');

module.exports = function(settings, photoId) {
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
        return client.search.query("OpenHouse", "OPENHOUSE", "(OpenHouseType=PUBLIC),(ActiveYN=1)")
        .then(function (results) {
          console.log("======== OpenHouse Query Results ========");
          //iterate through search results
          for (var dataItem = 0; dataItem < results.length; dataItem++) {
            console.log("-------- Open House " + dataItem + " --------");
            for (var fieldItem = 0; fieldItem < fields.length; fieldItem++) {
              var systemStr = fields[fieldItem].SystemName;
              console.log(systemStr + " : " + results[dataItem][systemStr]);
            }
            console.log("");
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
};
