const https = require('https');

const url = 'https://tkcdzuthjrxpfczqathy.supabase.co/rest/v1/';
const key = 'sb_publishable_CtJZjslr5h0rVC5_FMi2UQ_Q7bFuqcj';
const headers = { 'apikey': key, 'Authorization': 'Bearer ' + key };

function fetch(table) {
  return new Promise((resolve, reject) => {
    const req = https.get(url + table + '?select=*&limit=2', { headers }, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); } catch(e) { resolve(data); }
      });
    });
    req.on('error', reject);
  });
}

(async () => {
  const tables = ['profiles', 'activities', 'posts', 'post_likes', 'post_comments'];
  for (const t of tables) {
    try {
      const data = await fetch(t);
      console.log(`\n=== ${t} ===`);
      if (Array.isArray(data) && data.length > 0) {
        console.log('COLUMNS:', Object.keys(data[0]).join(', '));
        console.log('SAMPLE:', JSON.stringify(data[0], null, 2));
      } else {
        console.log('Empty or error:', JSON.stringify(data).substring(0, 200));
      }
    } catch(e) {
      console.log(`${t}: ERROR - ${e.message}`);
    }
  }
})();
