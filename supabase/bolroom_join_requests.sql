CREATE TABLE IF NOT EXISTS public.bolroom_join_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    community_id UUID REFERENCES public.bolroom_communities(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()),
    UNIQUE(community_id, user_id)
);

-- Enable RLS
ALTER TABLE public.bolroom_join_requests ENABLE ROW LEVEL SECURITY;

-- Allow users to see requests for communities they created, and their own requests
CREATE POLICY "Users can see join requests for communities they created or requested to join" 
ON public.bolroom_join_requests 
FOR SELECT 
USING (
  user_id = auth.uid() OR 
  EXISTS (
    SELECT 1 FROM public.bolroom_communities bc 
    WHERE bc.id = community_id AND bc.creator_id = auth.uid()
  )
);

-- Allow users to insert their own requests
CREATE POLICY "Users can insert their own join requests" 
ON public.bolroom_join_requests 
FOR INSERT 
WITH CHECK (user_id = auth.uid());

-- Allow community creators to update request status
CREATE POLICY "Community creators can update request status" 
ON public.bolroom_join_requests 
FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 FROM public.bolroom_communities bc 
    WHERE bc.id = community_id AND bc.creator_id = auth.uid()
  )
);
-- Allow community creators to delete requests
CREATE POLICY "Community creators can delete requests" 
ON public.bolroom_join_requests 
FOR DELETE 
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM public.bolroom_communities bc 
    WHERE bc.id = community_id AND bc.creator_id = auth.uid()
  )
);
