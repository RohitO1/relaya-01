const { createClient } = require('@supabase/supabase-js');

// Using SERVICE ROLE key to bypass RLS for diagnosis
const supabaseUrl = 'https://zlljvualqfjhbifhgabw.supabase.co';

// ANON KEY (this is what the Flutter app uses)
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs';

const supabase = createClient(supabaseUrl, anonKey);

async function main() {
  console.log('\n=== STEP 1: Check notifications table current count ===');
  const { data: existing, error: cntError } = await supabase
    .from('notifications').select('id').limit(1);
  if (cntError) {
    console.error('❌ Cannot even SELECT from notifications! RLS is blocking reads:', cntError.message);
  } else {
    console.log('✅ Can read notifications table. Rows visible:', existing.length);
  }

  console.log('\n=== STEP 2: Get a real user ID to test with ===');
  const { data: profiles } = await supabase
    .from('profiles').select('id, name').limit(3);
  if (!profiles || profiles.length === 0) {
    console.log('No profiles found. Aborting.');
    return;
  }
  const testUserId = profiles[0].id;
  console.log(`Using user: ${profiles[0].name} (${testUserId})`);

  console.log('\n=== STEP 3: Try inserting a test notification (as anon/unauthenticated) ===');
  console.log('Note: Flutter app inserts as authenticated user, not anon.');
  console.log('If this fails with RLS, it means Flutter inserts ALSO fail unless user is signed in.');
  const { data: insertData, error: insertError } = await supabase
    .from('notifications')
    .insert({
      user_id: testUserId,
      type: 'system',
      title: 'DIAGNOSTIC TEST',
      body: 'This is a test notification from the diagnostic script',
      is_read: false,
    })
    .select();

  if (insertError) {
    console.error('❌ INSERT FAILED:', insertError.message);
    console.error('   Code:', insertError.code);
    console.error('   Hint:', insertError.hint);
    console.log('\n>>> ROOT CAUSE: RLS is blocking notification inserts from the Flutter app.');
    console.log('>>> SOLUTION: Run the fix_rls_notifications.sql in Supabase SQL Editor.');
  } else {
    console.log('✅ Insert succeeded! Notification row created:', JSON.stringify(insertData));
    console.log('\n>>> If insert works but no FCM push arrives, the DB webhook trigger is broken.');
    console.log('>>> Check the Supabase Edge Function logs for "push-notification".');
  }

  console.log('\n=== STEP 4: Check recent activities for is_rush_in ===');
  const { data: acts } = await supabase
    .from('activities')
    .select('id, title, is_rush_in, radius_km, lat, lng, city, created_at')
    .order('created_at', { ascending: false })
    .limit(3);
  for (let a of (acts || [])) {
    console.log(`- ${a.title}: is_rush_in=${a.is_rush_in}, radius_km=${a.radius_km}, lat=${a.lat}, city=${a.city}`);
  }
}

main();
