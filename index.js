var Promise = require('bluebird');
var coffee = require('coffee-script');
coffee.register();

var replycodes = require('./lib/replycodes');
var Client = require('./lib/client');
var utils = require('./lib/utils');

/*  Available settings:
 *      loginUrl: RETS login URL (i.e http://<MLS_DOMAIN>/rets/login.ashx)
 *      username: username credential
 *      password: password credential
 *      version: rets version
 *
 *      //RETS-UA-Authorization
 *      userAgent
 *      userAgentPassword
 *      sessionId
 */
module.exports = {
  replycode: replycodes.codeMap,
  RetsReplyError: utils.RetsReplyError,
  Client: Client,
  getAutoLogoutClient: function(settings, handler) {
    var client = new Client(settings);
    return client.login()
    .then(handler)
    .finally(function() {
      return client.logout();
    });
  }
};
