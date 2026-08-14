const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:Kart%407905761080@db.zlljvualqfjhbifhgabw.supabase.co:5432/postgres'
});

async function main() {
  await client.connect();
  try {
    console.log('--- RECENT RUSH-INS/ACTIVITIES ---');
    const actRes = await client.query(`
      SELECT id, title, is_rush_in, lat, lng, created_at, radius_km
      FROM public.activities
      ORDER BY created_at DESC
      LIMIT 3
    `);
    for (let act of actRes.rows) {
      console.log(`ID: ${act.id}\nTitle: ${act.title}\nIs Rush-In: ${act.is_rush_in}\nCoords: [${act.lat}, ${act.lng}]\nRadius: ${act.radius_km}km\nCreated At: ${act.created_at}\n`);
    }

    console.log('--- RECENT NOTIFICATIONS ---');
    const notifRes = await client.query(`
      SELECT id, user_id, type, title, body, created_at
      FROM public.notifications
      ORDER BY created_at DESC
      LIMIT 5
    `);
    console.log(`Total notifications found: ${notifRes.rows.length}`);
    for (let n of notifRes.rows) {
      console.log(`- ID: ${n.id}\n  Type: ${n.type}\n  Title: ${n.title}\n  Body: ${n.body}\n  Target User ID: ${n.user_id}\n  Created At: ${n.created_at}\n`);
    }

    console.log('--- ALL FCM TOKENS ---');
    const fcmRes = await client.query(`
      SELECT user_id, fcm_token, updated_at
      FROM public.user_fcm_tokens
      LIMIT 10
    `);
    console.log(`Total FCM tokens: ${fcmRes.rows.length}`);
    for (let t of fcmRes.rows) {
      console.log(`- User: ${t.user_id}, Token: ${t.fcm_token.substring(0, 30)}..., Updated: ${t.updated_at}`);
    }
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await client.end();
  }
}

main();
