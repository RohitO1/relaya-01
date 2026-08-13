-- ================================================================
-- VOICEROOM AUTO-CLOSE FIX
-- Layer 1: DB Trigger - auto-delete room when last member leaves
-- Layer 2: Stale member cleanup via last_seen heartbeat
-- ================================================================

-- STEP 1: Add last_seen column to chatroom_members for heartbeat tracking
ALTER TABLE chatroom_members ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ DEFAULT NOW();

-- STEP 2: Trigger function - fires after any member is deleted
-- If the room is now empty, immediately delete the room
CREATE OR REPLACE FUNCTION auto_close_empty_chatroom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  remaining_count INTEGER;
BEGIN
  -- Count remaining members in this room
  SELECT COUNT(*) INTO remaining_count
  FROM chatroom_members
  WHERE room_id = OLD.room_id;

  -- If no one is left, destroy the room immediately
  IF remaining_count = 0 THEN
    UPDATE chatrooms SET room_status = 'deleted' WHERE id = OLD.room_id;
    DELETE FROM chatrooms WHERE id = OLD.room_id;
    RAISE NOTICE 'Auto-closed empty voice room: %', OLD.room_id;
  END IF;

  RETURN OLD;
END;
$$;

-- Drop and recreate the trigger cleanly
DROP TRIGGER IF EXISTS on_member_delete_close_empty_room ON chatroom_members;
CREATE TRIGGER on_member_delete_close_empty_room
  AFTER DELETE ON chatroom_members
  FOR EACH ROW
  EXECUTE FUNCTION auto_close_empty_chatroom();

-- STEP 3: Stale cleanup function
-- Removes members whose last_seen is > 2 minutes old (force-killed apps)
-- Then removes any rooms that are now empty as a result
CREATE OR REPLACE FUNCTION cleanup_stale_chatroom_members()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Remove stale members (app killed without graceful exit)
  DELETE FROM chatroom_members
  WHERE last_seen < NOW() - INTERVAL '2 minutes';

  -- Remove rooms that are empty (the trigger above should handle this,
  -- but this is a safety net for any edge cases)
  DELETE FROM chatrooms
  WHERE room_status = 'deleted'
     OR (id NOT IN (SELECT DISTINCT room_id FROM chatroom_members)
         AND created_at < NOW() - INTERVAL '2 minutes');

  RAISE NOTICE 'Stale chatroom member cleanup complete at %', NOW();
END;
$$;

-- STEP 4: Run cleanup immediately to remove any ghost rooms right now
SELECT cleanup_stale_chatroom_members();

SELECT 'Voice room auto-close system installed successfully!' AS status;

