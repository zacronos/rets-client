/*
 * Tags & Constant representation for reply codes
 *
*/
var tagCodeMap = {
  "NO_RECORDS_FOUND": 20201
};

/*
 * Expose the reverse lookup (both keys and values are unique)
 * Useful when sending errors generated in this library for
 *   intuitive association with available codes and tags.
*/
var codeTagMap = {};
for (var prop in tagCodeMap) {
  if (tagCodeMap.hasOwnProperty(prop)) {
    codeTagMap[tagCodeMap[prop]] = prop;
  }
}

module.exports.codeMap = tagCodeMap;
module.exports.tagMap = codeTagMap;