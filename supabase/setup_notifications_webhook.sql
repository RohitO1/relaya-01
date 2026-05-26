-- 1. Create the notifications table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    payload JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Create the FCM tokens table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    user_id UUID PRIMARY KEY,
    fcm_token TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Create the webhook function that performs the HTTP POST
CREATE OR REPLACE FUNCTION public.notify_insert_webhook()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM extensions.http_post(
    'https://tkcdzuthjrxpfczqathy.functions.supabase.co/push-notification',
    json_build_object(
      'type', 'INSERT',
      'table', 'notifications',
      'record', row_to_json(NEW)
    )::text,
    'application/json'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Drop the trigger if it already exists to avoid duplication errors
DROP TRIGGER IF EXISTS "on_notification_insert" ON "public"."notifications";

-- 5. Create the trigger to call our webhook function
CREATE TRIGGER "on_notification_insert"
AFTER INSERT ON "public"."notifications"
FOR EACH ROW
EXECUTE FUNCTION public.notify_insert_webhook();
