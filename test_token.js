const crypto = require('crypto');

const apiKey = 'APIDfmKbrgLtiNh';
const apiSecret = 'yG30Mfm7q2nDf3U9Sy5gaOkagZ2QWNfwGnfCFeGgq33G';
const identity = 'test-user-123';
const roomName = 'bolroom-test-room';

// ── Dart-style (what our app generates) ──────────────────────────
function b64NoPad(str) {
  return Buffer.from(str).toString('base64url');
}

const now = Math.floor(Date.now() / 1000);
const payload = {
  iss: apiKey,
  sub: identity,
  iat: now,
  nbf: now,
  exp: now + 21600,
  name: 'Test User',
  metadata: JSON.stringify({ avatarUrl: '' }),
  video: { roomJoin: true, room: roomName, canPublish: true, canSubscribe: true, canPublishData: true },
};

const header = '{"alg":"HS256","typ":"JWT"}';
const signingInput = `${b64NoPad(header)}.${b64NoPad(JSON.stringify(payload))}`;
const sig = crypto.createHmac('sha256', apiSecret).update(signingInput).digest('base64url');
const dartToken = `${signingInput}.${sig}`;

console.log('\n=== DART-STYLE TOKEN ===');
console.log(dartToken);
console.log('\nHeader b64:', b64NoPad(header));
console.log('Expected:   eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9');
console.log('\nPayload (decoded):', JSON.stringify(payload, null, 2));

// ── Official LiveKit SDK style ──────────────────────────────────
const { AccessToken } = require('livekit-server-sdk');
const at = new AccessToken(apiKey, apiSecret, {
  identity,
  name: 'Test User',
  metadata: JSON.stringify({ avatarUrl: '' }),
  ttl: '6h',
});
at.addGrant({ roomJoin: true, room: roomName, canPublish: true, canSubscribe: true, canPublishData: true });

at.toJwt().then(officialToken => {
  console.log('\n=== OFFICIAL LIVEKIT SDK TOKEN ===');
  console.log(officialToken);

  // Decode and compare payloads
  const dartPayloadDec = JSON.parse(Buffer.from(dartToken.split('.')[1], 'base64url').toString());
  const offPayloadDec  = JSON.parse(Buffer.from(officialToken.split('.')[1], 'base64url').toString());

  console.log('\n=== DIFF ===');
  const allKeys = new Set([...Object.keys(dartPayloadDec), ...Object.keys(offPayloadDec)]);
  let mismatch = false;
  for (const k of allKeys) {
    const d = JSON.stringify(dartPayloadDec[k]);
    const o = JSON.stringify(offPayloadDec[k]);
    if (d !== o) { console.log(`MISMATCH key="${k}"  dart=${d}  official=${o}`); mismatch = true; }
  }
  if (!mismatch) console.log('Payloads are structurally identical ✅');
});
