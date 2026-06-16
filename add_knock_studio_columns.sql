-- Add missing columns for Knock Studio settings
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS knock_questions jsonb DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS visibility_updated_at timestamptz;
