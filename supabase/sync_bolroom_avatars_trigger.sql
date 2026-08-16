-- ============================================================
-- BOLROOM MISSING ALIGNMENT TRIGGER & SCHEMA UPDATE
-- Execute this in your Supabase SQL Editor.
-- This expands the database to properly support Gallery uploads.
-- ============================================================

-- 1. Add the missing Gallery URL column to legacy messages
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bolroom_community_messages' AND column_name='custom_avatar_url') THEN
    ALTER TABLE bolroom_community_messages ADD COLUMN custom_avatar_url TEXT DEFAULT '';
  END IF;
END $$;

-- 2. Update the sync trigger function to include custom_avatar_url
CREATE OR REPLACE FUNCTION sync_bolroom_profile_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.avatar_key IS DISTINCT FROM NEW.avatar_key 
     OR OLD.anon_name IS DISTINCT FROM NEW.anon_name
     OR OLD.custom_avatar_url IS DISTINCT FROM NEW.custom_avatar_url THEN
     
    UPDATE bolroom_community_messages
    SET 
        avatar_key = NEW.avatar_key,
        anon_name = NEW.anon_name,
        custom_avatar_url = NEW.custom_avatar_url
    WHERE user_id = NEW.id;
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Bind the trigger safely onto the bolroom_profiles table
DROP TRIGGER IF EXISTS trigger_sync_bolroom_profile ON bolroom_profiles;

CREATE TRIGGER trigger_sync_bolroom_profile
AFTER UPDATE ON bolroom_profiles
FOR EACH ROW
EXECUTE FUNCTION sync_bolroom_profile_changes();

-- 4. Automatically retroactive sync to fix existing out-of-sync messages (One-time repair)
UPDATE bolroom_community_messages bcm
SET 
    avatar_key = bp.avatar_key,
    anon_name = bp.anon_name,
    custom_avatar_url = bp.custom_avatar_url
FROM bolroom_profiles bp
WHERE bcm.user_id = bp.id
  AND (bcm.avatar_key IS DISTINCT FROM bp.avatar_key 
       OR bcm.anon_name IS DISTINCT FROM bp.anon_name 
       OR bcm.custom_avatar_url IS DISTINCT FROM bp.custom_avatar_url);
