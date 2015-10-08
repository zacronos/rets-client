# Tags & Constant representation for reply codes
 
# authoritative documentation for all reply codes in current rets standard:
# http://www.reso.org/assets/RETS/Specifications/rets_1_8.pdf

# Search codes that are covered:
# Search Transaction Reply Codes
tagCodeMap =
  OPERATION_SUCCESSFUL: 0
  UNKNOWN_QUERY_FIELD: 20200
  NO_RECORDS_FOUND: 20201
  INVALID_SELECT: 20202
  MISC_SEARCH_ERROR: 20203
  INVALID_QUERY_SYNTAX: 20206
  UNAUTH_QUERY: 20207
  MAX_RECORDS_EXCEEDED: 20208
  TIMEOUT: 20209
  TOO_MANY_ACTIVE_QUERIES: 20210
  QUERY_TOO_COMPLEX: 20211
  INVALID_KEY_REQUEST: 20212
  INVALID_KEY: 20213
  REQ_DTD_VERSION_UNAVAIL: 20514


# Expose the reverse lookup (both keys and values are unique)
# Useful when sending errors generated in this library for
#   intuitive association with available codes and tags.
codeTagMap = {};
for k, v of tagCodeMap
  codeTagMap[v] = k

module.exports =
  codeMap: tagCodeMap
  tagMap: codeTagMap
