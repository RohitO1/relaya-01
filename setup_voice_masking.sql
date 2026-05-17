ALTER TABLE bolroom_profiles 
ADD COLUMN IF NOT EXISTS voice_mask_enabled BOOLEAN DEFAULT FALSE;

ALTER TABLE bolroom_profiles 
ADD COLUMN IF NOT EXISTS voice_mask_preset TEXT DEFAULT 'ghost';

ALTER TABLE bolroom_profiles 
ADD COLUMN IF NOT EXISTS voice_pitch NUMERIC DEFAULT 0.5;

-- Enable real-time for bolroom_profiles so the screens can sync instantly
ALTER PUBLICATION supabase_realtime ADD TABLE bolroom_profiles;
