const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://zlljvualqfjhbifhgabw.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs';
const supabase = createClient(supabaseUrl, supabaseKey);

async function main() {
  try {
    // Fetch one activity to see what columns exist
    const { data, error } = await supabase
      .from('activities')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(1);
    if (error) throw error;
    if (data && data.length > 0) {
      console.log('All activity columns:', Object.keys(data[0]));
      console.log('Sample record:');
      console.log(JSON.stringify(data[0], null, 2));
    } else {
      console.log('No activities found');
    }
  } catch (error) {
    console.error('Error:', error);
  }
}

main();
