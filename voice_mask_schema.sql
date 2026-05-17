-- ============================================
-- Voice Masking Schema Migration
-- Run this in Supabase SQL Editor
-- ============================================

-- Add voice_mask_preset column to bolroom_profiles
ALTER TABLE bolroom_profiles
  ADD COLUMN IF NOT EXISTS voice_mask_preset TEXT DEFAULT 'ghost';

-- Backfill existing rows that have masking enabled
UPDATE bolroom_profiles
  SET voice_mask_preset = 'ghost'
  WHERE voice_mask_preset IS NULL;

-- Optional: Add a check constraint for valid presets
-- ALTER TABLE bolroom_profiles
--   ADD CONSTRAINT valid_voice_preset
--   CHECK (voice_mask_preset IN ('ghost','shadow','robot','chipmunk','titan','alien','custom','none'));

-- Verify
SELECT id, anon_name, voice_mask_enabled, voice_pitch, voice_mask_preset
  FROM bolroom_profiles
  LIMIT 5;
