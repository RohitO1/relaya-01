-- Run this query in your Supabase SQL Editor to add the missing columns

ALTER TABLE public.activities
ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS radius_km NUMERIC DEFAULT 5.0;

-- This notifies PostgREST to reload its schema cache
NOTIFY pgrst, 'reload schema';
