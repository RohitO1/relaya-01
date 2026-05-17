// This script verifies the LiveKit API key by calling the server's REST API
const { RoomServiceClient, AccessToken } = require('livekit-server-sdk');

const apiKey    = 'APIDfmKbrgLtiNh';
const apiSecret = 'yG30Mfm7q2nDf3U9Sy5gaOkagZ2QWNfwGnfCFeGgq33G';
const host      = 'https://meetra-qpnmu7vr.livekit.cloud';

console.log('=== Testing LiveKit credentials ===');
console.log('Host:', host);
console.log('Key :', apiKey);

// 1) Try to list rooms — proves the API key is recognised by the server
const svc = new RoomServiceClient(host, apiKey, apiSecret);
svc.listRooms()
  .then(rooms => {
    console.log('\n✅ API key VALID — rooms list returned:', rooms.length, 'rooms');
    rooms.forEach(r => console.log('  room:', r.name));
  })
  .catch(err => {
    console.log('\n❌ API key INVALID or network error:', err.message);
    console.log('Full error:', err);
  });

// 2) Also print a sample token for visual inspection
const at = new AccessToken(apiKey, apiSecret, { identity: 'diag-test', ttl: '1h' });
at.addGrant({ roomJoin: true, room: 'diag-room', canPublish: true, canSubscribe: true });
at.toJwt().then(token => {
  const parts = token.split('.');
  const hdr = JSON.parse(Buffer.from(parts[0], 'base64url'));
  const pay = JSON.parse(Buffer.from(parts[1], 'base64url'));
  console.log('\n=== Official SDK token ===');
  console.log('Header :', JSON.stringify(hdr));
  console.log('Payload:', JSON.stringify(pay));
  console.log('Full   :', token);
});
