-- Add game_mode column to chatrooms table
-- Run this in your Supabase SQL editor

ALTER TABLE chatrooms
ADD COLUMN IF NOT EXISTS game_mode TEXT DEFAULT NULL;

-- Add comment for documentation
COMMENT ON COLUMN chatrooms.game_mode IS 'Game mode for the room: null=normal, truth_dare=Truth or Dare game';
