-- ============================================================
-- FIX: Notifications pipeline
-- Root cause: 'http' extension missing → trigger crashes →
-- notification INSERT rolls back → table stays empty forever
-- Solution: switch to pg_net (built-in Supabase async HTTP)
-- ============================================================

-- 1. Enable pg_net if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- 2. Replace the broken webhook function with pg_net version
CREATE OR REPLACE FUNCTION public.notify_insert_webhook()
RETURNS TRIGGER AS $$
DECLARE
  payload TEXT;
BEGIN
  -- Build the JSON payload
  payload := json_build_object(
    'type', 'INSERT',
    'table', 'notifications',
    'record', row_to_json(NEW)
  )::text;

  -- Use pg_net for non-blocking async HTTP POST (won't crash the INSERT if it fails)
  PERFORM extensions.http_post(
    url     := 'https://zlljvualqfjhbifhgabw.functions.supabase.co/push-notification',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs"}'::jsonb,
    body    := payload::jsonb
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error but never let the trigger crash the INSERT
  RAISE WARNING 'notify_insert_webhook error: % %', SQLERRM, SQLSTATE;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Recreate the trigger
DROP TRIGGER IF EXISTS on_notification_insert ON public.notifications;
CREATE TRIGGER on_notification_insert
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_insert_webhook();
