-- Run this query in your Supabase SQL Editor to add the missing columns for compliment chat lock

ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS compliment_status TEXT DEFAULT NULL;
-- Values: NULL (normal message), 'pending' (awaiting receiver action), 
--         'accepted' (chat unlocked), 'rejected' (chat deleted)

-- This notifies PostgREST to reload its schema cache
NOTIFY pgrst, 'reload schema';
