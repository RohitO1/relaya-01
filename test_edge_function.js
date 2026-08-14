const https = require('https');

// Test: manually call the edge function with a real notification record
const data = JSON.stringify({
  type: 'INSERT',
  table: 'notifications',
  record: {
    id: 999,
    user_id: 'c031e919-53a0-4d52-8981-81e8a49f4ee0', // User with FCM token: f_AOkUZgT4...
    type: 'knock',
    title: '🔔 LIVE PUSH TEST',
    body: 'If you see this popup, push notifications are working!',
    payload: { sender_id: 'test' },
    is_read: false,
    created_at: new Date().toISOString()
  }
});

const options = {
  hostname: 'zlljvualqfjhbifhgabw.functions.supabase.co',
  port: 443,
  path: '/push-notification',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs',
    'Content-Length': Buffer.byteLength(data)
  }
};

const req = https.request(options, (res) => {
  let body = '';
  res.on('data', chunk => body += chunk);
  res.on('end', () => {
    console.log('Status:', res.statusCode);
    console.log('Response:', body);
  });
});

req.on('error', (e) => console.error('Error:', e));
req.write(data);
req.end();
