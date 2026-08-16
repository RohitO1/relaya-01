-- Create the rush_in_messages table
CREATE TABLE IF NOT EXISTS public.rush_in_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID REFERENCES public.activities(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Turn on Row Level Security
ALTER TABLE public.rush_in_messages ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to select all messages (could be restricted to activity members later)
CREATE POLICY "Users can view messages of activities"
ON public.rush_in_messages FOR SELECT
TO authenticated
USING (true);

-- Allow users to insert their own messages
CREATE POLICY "Users can insert their own messages"
ON public.rush_in_messages FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own messages
CREATE POLICY "Users can delete their own messages"
ON public.rush_in_messages FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Enable realtime broadcasting for the table
BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime FOR ALL TABLES;
COMMIT;
-- Ensure we add it specifically if 'FOR ALL TABLES' is not used, but 'FOR ALL TABLES' is safer.
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.rush_in_messages;
