-- Create the rush_in_chat_status table
CREATE TABLE IF NOT EXISTS public.rush_in_chat_status (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id uuid NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status text NOT NULL, -- 'removed', 'requested', 'allowed'
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(activity_id, user_id)
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.rush_in_chat_status ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view their own chat status or host can view all" ON public.rush_in_chat_status;
DROP POLICY IF EXISTS "Users can insert their own status or host can insert any" ON public.rush_in_chat_status;
DROP POLICY IF EXISTS "Users can update their own status or host can update any" ON public.rush_in_chat_status;
DROP POLICY IF EXISTS "Host can delete chat status" ON public.rush_in_chat_status;

-- Create Policies
CREATE POLICY "Users can view their own chat status or host can view all" ON public.rush_in_chat_status
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id
    OR auth.uid() = (SELECT user_id FROM public.activities WHERE id = activity_id)
  );

CREATE POLICY "Users can insert their own status or host can insert any" ON public.rush_in_chat_status
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    OR auth.uid() = (SELECT user_id FROM public.activities WHERE id = activity_id)
  );

CREATE POLICY "Users can update their own status or host can update any" ON public.rush_in_chat_status
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = user_id
    OR auth.uid() = (SELECT user_id FROM public.activities WHERE id = activity_id)
  );

CREATE POLICY "Host can delete chat status" ON public.rush_in_chat_status
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = (SELECT user_id FROM public.activities WHERE id = activity_id)
  );

-- Update RLS policies on rush_in_messages to block removed users
DROP POLICY IF EXISTS "Users can read messages if they are the host or candidate" ON public.rush_in_messages;
DROP POLICY IF EXISTS "Users can insert messages if they are the host or candidate" ON public.rush_in_messages;

CREATE POLICY "Users can read messages if they are the host or candidate" ON public.rush_in_messages
  FOR SELECT
  TO authenticated
  USING (
    (
      auth.uid() = (SELECT user_id FROM public.activities WHERE id = activity_id)
      OR EXISTS (
        SELECT 1 FROM public.requests 
        WHERE target_id = activity_id 
          AND sender_id = auth.uid() 
          AND status IN ('approved', 'pending')
      )
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.rush_in_chat_status 
      WHERE activity_id = rush_in_messages.activity_id 
        AND user_id = auth.uid() 
        AND status = 'removed'
    )
  );

CREATE POLICY "Users can insert messages if they are the host or candidate" ON public.rush_in_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND (
      auth.uid() = (SELECT user_id FROM public.activities WHERE id = activity_id)
      OR EXISTS (
        SELECT 1 FROM public.requests 
        WHERE target_id = activity_id 
          AND sender_id = auth.uid() 
          AND status IN ('approved', 'pending')
      )
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.rush_in_chat_status 
      WHERE activity_id = rush_in_messages.activity_id 
        AND user_id = auth.uid() 
        AND status = 'removed'
    )
  );

-- Add to Realtime publication if not already present
-- (Avoid duplicate error by checking if it exists in publication first or catch error in query)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'rush_in_chat_status'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rush_in_chat_status;
  END IF;
END $$;
