const { AccessToken } = require('livekit-server-sdk');

const apiKey = "APIDfmKbrgLtiNh";
const apiSecret = "yG30Mfm7q2nDf3U9Sy5gaOkagZ2QWNfwGnfCFeGgq33G";

const at = new AccessToken(apiKey, apiSecret, {
  identity: "test-user-123",
  name: "Test User",
  metadata: JSON.stringify({ avatarUrl: "" }),
  ttl: "6h",
});

at.addGrant({
  roomJoin: true,
  room: "bolroom-test",
  canPublish: true,
  canSubscribe: true,
  canPublishData: true,
});

at.toJwt().then((token) => {
  console.log("NODE GENERATED TOKEN:");
  console.log(token);
  
  // print payload
  const parts = token.split('.');
  console.log("PAYLOAD:");
  console.log(Buffer.from(parts[1], 'base64').toString());
});
