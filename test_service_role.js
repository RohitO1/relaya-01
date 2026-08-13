const { createClient } = require('@supabase/supabase-js');

// Using SERVICE ROLE KEY
const supabaseUrl = 'https://zlljvualqfjhbifhgabw.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NjUwMTU0MSwiZXhwIjoyMTAyMDc3NTQxfQ.m-a_65VfE398w6_sZgCsz4N_q0pW12zR-t7O5E-8178';
const supabase = createClient(supabaseUrl, supabaseKey);

async function checkRLS() {
  // We can't query pg_policies directly through postgrest easily unless it's exposed. 
  // Let's try inserting a record with service role key. If it works, the table works.
  console.log('Testing insert with Service Role Key (bypasses RLS)...');
  const { data, error } = await supabase.from('notifications').insert({
    user_id: '00000000-0000-0000-0000-000000000000', // Fake UUID
    type: 'system',
    title: 'Test Notification',
    body: 'Test Body'
  }).select();

  if (error) {
    console.error('Insert with Service Role failed:', error);
  } else {
    console.log('Insert with Service Role succeeded:', data);
    
    // Now delete it
    await supabase.from('notifications').delete().eq('id', data[0].id);
  }
}

checkRLS();
