#### 4.4.0
Added a new `parserEncoding` param for `client.search.query()` and `client.search.stream.query()` calls, defaulting to
UTF-8.

#### 4.3.0
Added support for TimeZoneOffset and Comments in the `metadata.getSystem()` call response.

#### 4.2.0
Improved error handling and error classes.  See the [error documentation](https://github.com/sbruno81/rets-client#errors).

#### 4.1.0

Added client configuration option to use POST instead of GET for all requests, as this seems to work better for some
RETS servers.

#### 4.0.0

Version 4.0!  This represents a substantial rewrite of the object-retrieval code, making it more robust and flexible,
adding support for streaming object results, and allowing for additional query options (like `Location` and
`ObjectData`).  See the simple photo query example at the end of the [Example RETS Session](https://github.com/sbruno81/rets-client#example-rets-session), and
the [photo streaming example](https://github.com/sbruno81/rets-client#photo-streaming-example).

Also new in version 4.0, just about every API call now gives access to header info from the RETS response.  For some
queries, in particular object queries, headers are often used as a vehicle for important metadata about the response,
so this is an important feature.  The exact mechanism varies depending on whether it a call that resolves to a stream
(which now emits a `headerInfo` event) or a call that resolves to an object (which now has a `headerInfo` field).  Also,
the RetsServerError and RetsReplyError objects now both contain a `headerInfo` field.

#### 3.3.0

Version 3.3 adds support for debugging via the [debug](https://github.com/visionmedia/debug) and
[request-debug](https://github.com/request/request-debug) modules. See the [debugging section](https://github.com/sbruno81/rets-client#debugging).

#### 3.2.2

Version 3.2.2 adds support for per-object errors when calling `client.objects.getPhotos()`.  The
[Example RETS Session](#example-rets-session) illustrates proper error checking.

#### 3.2.0

Version 3.2 passes through any multipart headers (except for content-disposition, which gets split up first;
content-type which is renamed to `mime`; and content-transfer-encoding which is used internally and not passed) onto
the objects resolved from `client.objects.getPhotos()`. It also fixes a race condition in `client.objects.getPhotos()`.

#### 3.1.0

Version 3.1 adds a `response` field to the object resolved from `client.objects.getObject()`, containing the full HTTP
response object.  It also fixes a major bug interfering with `client.objects.getPhotos()` and
`client.objects.getObject()` calls.

#### 3.0.0

Version 3.x is out!  This represents a substantial rewrite of the underlying code, which should improve performance
(both CPU and memory use) for almost all RETS calls by using node-expat instead of xml2js for xml parsing.  The changes
are mostly internal, however there is 1 small backward-incompatible change needed for correctness, described below.
The large internal refactor plus even a small breaking change warrants a major version bump.

Version 3.x has almost the same interface as 2.x, which is completely different from 1.x.  If you wish to continue to
use the 1.x version, you can use the [v1 branch](https://github.com/sbruno81/rets-client/tree/v1).

Many of the metadata methods are capable of returning multiple sets of data, including (but not limited to) the
getAll* methods.  Versions 1.x and 2.x did not handle this properly; ~~version 1.x returns the values from the last set
encountered~~, and version 2.x returns the values from the first set encountered.  (This has been corrected in version
1.2.0.)  Version 3.x always returns all values encountered, by returning an array of data sets rather than a single one.  

In addition to the methods available in 2.x, version 3.0 adds `client.search.stream.searchRets()`, which returns a
text stream of the raw XML result, and `client.search.stream.query()`, which returns a stream of low-level objects
parsed from the XML.  (See the [streaming example](https://github.com/sbruno81/rets-client#simple-streaming-example) below.)  These streams, if used properly,
should result in a much lower memory footprint than their corresponding non-streaming counterparts.
