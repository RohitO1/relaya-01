const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://zlljvualqfjhbifhgabw.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs';
const supabase = createClient(supabaseUrl, supabaseKey);

async function main() {
  try {
    console.log('--- RECENT RUSH-INS/ACTIVITIES ---');
    const { data: activities, error: aError } = await supabase
      .from('activities')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(3);
    if (aError) throw aError;
    
    for (let act of activities) {
      console.log(`ID: ${act.id}\nTitle: ${act.title}\nIs Rush-In: ${act.is_rush_in}\nCoords: [${act.lat}, ${act.lng}]\nCity: ${act.city}\nCreated At: ${act.created_at}\n`);
    }

    console.log('\n--- ACTIVE USER PROFILES ---');
    const { data: profiles, error: pError } = await supabase
      .from('profiles')
      .select('id, name, lat, lng, city')
      .limit(10);
    if (pError) throw pError;
    
    for (let p of profiles) {
      console.log(`User: ${p.name} (${p.id})\nCoords: [${p.lat}, ${p.lng}]\nCity: ${p.city}\n`);
    }
  } catch (error) {
    console.error('Error:', error);
  }
}

main();
