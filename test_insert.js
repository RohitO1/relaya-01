const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://zlljvualqfjhbifhgabw.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs';
const supabase = createClient(supabaseUrl, supabaseKey);

async function main() {
  try {
    console.log('Testing insert to notifications...');
    const { data, error } = await supabase.from('notifications').insert({
      user_id: '00000000-0000-0000-0000-000000000000',
      type: 'system',
      title: 'test',
      body: 'test'
    }).select();
    
    if (error) {
      console.error('Insert failed:', error.message, error.details, error.hint);
    } else {
      console.log('Insert success:', data);
    }
  } catch (error) {
    console.error('Exception:', error);
  }
}

main();
