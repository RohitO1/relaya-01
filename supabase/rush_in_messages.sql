-- Create the rush_in_messages table
CREATE TABLE IF NOT EXISTS public.rush_in_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id uuid NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  text text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.rush_in_messages ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can read messages if they are the host or candidate" ON public.rush_in_messages;
DROP POLICY IF EXISTS "Users can insert messages if they are the host or candidate" ON public.rush_in_messages;

-- Create Select Policy
CREATE POLICY "Users can read messages if they are the host or candidate" ON public.rush_in_messages
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = (SELECT user_id FROM public.activities WHERE id = activity_id)
    OR EXISTS (
      SELECT 1 FROM public.requests 
      WHERE target_id = activity_id 
        AND sender_id = auth.uid() 
        AND status IN ('approved', 'pending')
    )
  );

-- Create Insert Policy
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
  );

-- Add to Realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.rush_in_messages;
