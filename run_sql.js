const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres.zlljvualqfjhbifhgabw:Kart@7905761080@aws-0-ap-south-1.pooler.supabase.com:6543/postgres'
});

async function runSQL() {
  await client.connect();
  
  const sql = `
-- Enable RLS on tables if not already enabled
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------
-- Policies for 'notifications' table
-- ----------------------------------------------------

-- Drop existing policies if they exist (to avoid errors if run multiple times)
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Anyone can insert notifications" ON public.notifications;

-- 1. Select: Users can view their own notifications
CREATE POLICY "Users can view their own notifications"
ON public.notifications
FOR SELECT
USING (auth.uid() = user_id);

-- 2. Update: Users can update their own notifications (e.g., mark as read)
CREATE POLICY "Users can update their own notifications"
ON public.notifications
FOR UPDATE
USING (auth.uid() = user_id);

-- 3. Delete: Users can delete their own notifications
CREATE POLICY "Users can delete their own notifications"
ON public.notifications
FOR DELETE
USING (auth.uid() = user_id);

-- 4. Insert: Authenticated users can insert notifications (to notify others)
CREATE POLICY "Anyone can insert notifications"
ON public.notifications
FOR INSERT
WITH CHECK (auth.role() = 'authenticated');


-- ----------------------------------------------------
-- Policies for 'user_fcm_tokens' table
-- ----------------------------------------------------

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own FCM tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Users can insert/update their own FCM tokens" ON public.user_fcm_tokens;

-- 1. Select: Users can view their own FCM tokens
CREATE POLICY "Users can view their own FCM tokens"
ON public.user_fcm_tokens
FOR SELECT
USING (auth.uid() = user_id);

-- 2. Insert: Users can insert their own FCM tokens
CREATE POLICY "Users can insert their own FCM tokens"
ON public.user_fcm_tokens
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- 3. Update: Users can update their own FCM tokens
CREATE POLICY "Users can update their own FCM tokens"
ON public.user_fcm_tokens
FOR UPDATE
USING (auth.uid() = user_id);
  `;

  try {
    const res = await client.query(sql);
    console.log('SQL executed successfully!');
  } catch (err) {
    console.error('Error executing SQL:', err);
  } finally {
    await client.end();
  }
}

runSQL();
