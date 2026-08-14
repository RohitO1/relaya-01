const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:Kart%407905761080@db.zlljvualqfjhbifhgabw.supabase.co:5432/postgres'
});

async function runSQL() {
  await client.connect();
  
  const sql = `
-- Enable RLS (in case it was disabled)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Drop ALL existing notification INSERT policies to start clean
DROP POLICY IF EXISTS "Anyone can insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "authenticated_can_insert_notifications" ON public.notifications;
DROP POLICY IF EXISTS "Authenticated users can insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "allow_authenticated_insert" ON public.notifications;

-- THE FIX: Allow any authenticated user to insert a notification for any other user
CREATE POLICY "authenticated_can_insert_notifications"
ON public.notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Allow users to read their own notifications
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
CREATE POLICY "Users can view their own notifications"
ON public.notifications
FOR SELECT
USING (auth.uid() = user_id);

-- Allow users to update (mark as read) their own notifications
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
CREATE POLICY "Users can update their own notifications"
ON public.notifications
FOR UPDATE
USING (auth.uid() = user_id);

-- Allow users to delete their own notifications
DROP POLICY IF EXISTS "Users can delete their own notifications" ON public.notifications;
CREATE POLICY "Users can delete their own notifications"
ON public.notifications
FOR DELETE
USING (auth.uid() = user_id);

-- user_fcm_tokens policies
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own FCM tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Users can insert their own FCM tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Users can update their own FCM tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "service_can_read_fcm_tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Users can manage their own FCM token" ON public.user_fcm_tokens;

CREATE POLICY "Users can manage their own FCM token"
ON public.user_fcm_tokens
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Webhook triggers
CREATE EXTENSION IF NOT EXISTS pg_net;
DROP TRIGGER IF EXISTS on_notification_insert ON public.notifications;
DROP TRIGGER IF EXISTS notify_push_on_insert ON public.notifications;
DROP FUNCTION IF EXISTS public.notify_insert_webhook();
DROP FUNCTION IF EXISTS public.notify_push_on_insert();

CREATE OR REPLACE FUNCTION public.notify_insert_webhook()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM net.http_post(
    url     := 'https://zlljvualqfjhbifhgabw.functions.supabase.co/push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs'
    ),
    body    := jsonb_build_object(
      'type',   'INSERT',
      'table',  'notifications',
      'record', row_to_json(NEW)
    )
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Push notification webhook error: % %', SQLERRM, SQLSTATE;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_notification_insert
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_insert_webhook();
  `;

  try {
    await client.query(sql);
    console.log('✅ SQL executed successfully directly on Supabase via Host 5432!');
  } catch (err) {
    console.error('❌ Error executing SQL:', err);
  } finally {
    await client.end();
  }
}

runSQL();
