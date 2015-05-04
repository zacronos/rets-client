var integrationTest = require('./simple-integration');
integrationTest({
  loginUrl: process.env.RETS_URL,
  username: process.env.RETS_LOGIN,
  password: process.env.RETS_PASSWORD
}, process.env.RETS_PHOTO_ID);
