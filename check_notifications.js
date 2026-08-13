const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://zlljvualqfjhbifhgabw.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs';
const supabase = createClient(supabaseUrl, supabaseKey);

async function main() {
  try {
    console.log('Checking notifications...');
    const { data: notifications, error: nError } = await supabase.from('notifications').select('*').limit(5).order('created_at', { ascending: false });
    if (nError) throw nError;
    console.log(`Recent notifications: ${notifications.length}`);
    for (let n of notifications) {
      console.log(`- ${n.type}: ${n.title} -> ${n.body} (user: ${n.user_id})`);
    }

    console.log('\nChecking FCM tokens...');
    const { data: tokens, error: tError } = await supabase.from('user_fcm_tokens').select('*').limit(5);
    if (tError) throw tError;
    console.log(`FCM Tokens: ${tokens.length}`);
    for (let t of tokens) {
      console.log(`- User: ${t.user_id}, Token: ${t.fcm_token.substring(0, Math.min(20, t.fcm_token.length))}...`);
    }
  } catch (error) {
    console.error('Error:', error);
  }
}

main();
