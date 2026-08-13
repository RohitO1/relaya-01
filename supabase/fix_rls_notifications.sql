-- ----------------------------------------------------
-- Fix RLS Policies for Notifications and FCM Tokens
-- ----------------------------------------------------

-- 1. Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing policies to avoid duplication errors
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Anyone can insert notifications" ON public.notifications;

DROP POLICY IF EXISTS "Users can view their own FCM tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Users can insert their own FCM tokens" ON public.user_fcm_tokens;
DROP POLICY IF EXISTS "Users can update their own FCM tokens" ON public.user_fcm_tokens;

-- 3. Notifications Policies
CREATE POLICY "Users can view their own notifications"
ON public.notifications FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications"
ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own notifications"
ON public.notifications FOR DELETE USING (auth.uid() = user_id);

-- IMPORTANT: Authenticated users can insert notifications for ANY user (e.g., sending a knock to someone else)
CREATE POLICY "Anyone can insert notifications"
ON public.notifications FOR INSERT WITH CHECK (auth.role() = 'authenticated');


-- 4. FCM Tokens Policies
CREATE POLICY "Users can view their own FCM tokens"
ON public.user_fcm_tokens FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own FCM tokens"
ON public.user_fcm_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own FCM tokens"
ON public.user_fcm_tokens FOR UPDATE USING (auth.uid() = user_id);
