-- Run this in your Supabase SQL Editor
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS reply_to_id          uuid,
  ADD COLUMN IF NOT EXISTS reply_to_text         text,
  ADD COLUMN IF NOT EXISTS reply_to_sender       text,
  ADD COLUMN IF NOT EXISTS deleted_for_sender    boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS deleted_for_everyone  boolean DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_messages_receiver_unread
  ON messages (receiver_id, is_read)
  WHERE is_read = false;
