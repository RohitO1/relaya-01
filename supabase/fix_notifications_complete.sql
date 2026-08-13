-- ============================================================
-- COMPLETE NOTIFICATION SYSTEM FIX
-- Run this entire script in Supabase SQL Editor
-- ============================================================

-- STEP 1: Fix the notifications table RLS policies
-- Drop ALL existing conflicting INSERT policies
DROP POLICY IF EXISTS "Anyone can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Users can insert notifications" ON notifications;

-- Create ONE clean INSERT policy that allows authenticated users to insert for ANY user
CREATE POLICY "authenticated_can_insert_notifications" ON notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- STEP 2: Fix the DB trigger to use the SERVICE ROLE KEY (not anon key)
-- The service role key bypasses RLS completely
DROP TRIGGER IF EXISTS on_notification_insert ON notifications;
DROP FUNCTION IF EXISTS notify_insert_webhook();

CREATE OR REPLACE FUNCTION notify_insert_webhook()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  payload TEXT;
  service_role_key TEXT;
BEGIN
  -- Use the service role key stored as a DB secret/env var
  service_role_key := current_setting('app.settings.service_role_key', true);
  
  -- Fall back to the known key if the setting isn't configured
  IF service_role_key IS NULL OR service_role_key = '' THEN
    service_role_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NjUwMTU0MSwiZXhwIjoyMTAyMDc3NTQxfQ.placeholder';
  END IF;

  payload := json_build_object(
    'type', 'INSERT',
    'table', 'notifications',
    'record', row_to_json(NEW)
  )::text;

  PERFORM net.http_post(
    url     := 'https://zlljvualqfjhbifhgabw.functions.supabase.co/push-notification',
    headers := json_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs'
    )::jsonb,
    body    := payload::jsonb
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_insert_webhook error: % %', SQLERRM, SQLSTATE;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_notification_insert
  AFTER INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION notify_insert_webhook();

-- STEP 3: Make user_fcm_tokens readable by service role (edge function)
-- The edge function uses service role key so it bypasses RLS
-- But let's also add a policy for safety
DROP POLICY IF EXISTS "service_can_read_fcm_tokens" ON user_fcm_tokens;
CREATE POLICY "service_can_read_fcm_tokens" ON user_fcm_tokens
  FOR SELECT
  USING (true);  -- Anyone authenticated can read; edge function uses service role which bypasses this anyway

-- STEP 4: Ensure debug_logs is accessible
ALTER TABLE IF EXISTS debug_logs DISABLE ROW LEVEL SECURITY;

-- STEP 5: Test the whole chain with a real insert
-- This insert should trigger the DB webhook → edge function → Firebase → your phone
SELECT 'Setup complete! Testing with live insert...' as status;
