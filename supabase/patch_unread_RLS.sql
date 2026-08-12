-- Fix RLS policy to allow the receiver to mark messages as read
CREATE POLICY "Users can update messages sent to them" 
ON public.messages
FOR UPDATE 
USING (auth.uid() = receiver_id)
WITH CHECK (auth.uid() = receiver_id);
