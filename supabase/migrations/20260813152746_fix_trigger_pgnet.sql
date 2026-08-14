-- Fix trigger to use correct pg_net syntax
CREATE OR REPLACE FUNCTION public.notify_insert_webhook()
RETURNS TRIGGER AS $$
DECLARE
  payload TEXT;
BEGIN
  payload := json_build_object(
    'type', 'INSERT',
    'table', 'notifications',
    'record', row_to_json(NEW)
  )::text;

  -- pg_net: async, non-blocking HTTP call — won't roll back the INSERT if it fails
  PERFORM net.http_post(
    url     := 'https://zlljvualqfjhbifhgabw.functions.supabase.co/push-notification',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsbGp2dWFscWZqaGJpZmhnYWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MDE1NDEsImV4cCI6MjEwMjA3NzU0MX0.NOxdtUTy9FLyfFVfJPV9Jd_tlhZEVyfPaHdmZi6G_Fs"}'::jsonb,
    body    := payload::jsonb
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_insert_webhook error: % %', SQLERRM, SQLSTATE;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
DROP TRIGGER IF EXISTS on_notification_insert ON public.notifications;
CREATE TRIGGER on_notification_insert
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_insert_webhook();
