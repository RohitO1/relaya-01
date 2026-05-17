-- ============================================================
-- VOICEROOM UPGRADE — Add missing columns for full spec
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. chatrooms table — add missing room-level fields
ALTER TABLE chatrooms ADD COLUMN IF NOT EXISTS visibility TEXT DEFAULT 'public';          -- 'public', 'friends', 'invite'
ALTER TABLE chatrooms ADD COLUMN IF NOT EXISTS max_participants INTEGER DEFAULT 0;        -- 0 = unlimited
ALTER TABLE chatrooms ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ DEFAULT NULL;     -- null = go live immediately
ALTER TABLE chatrooms ADD COLUMN IF NOT EXISTS room_status TEXT DEFAULT 'active';         -- 'active', 'scheduled', 'deleted'
ALTER TABLE chatrooms ADD COLUMN IF NOT EXISTS participant_count INTEGER DEFAULT 0;       -- live counter

-- 2. chatroom_members — add hand_raised and host_muted fields
ALTER TABLE chatroom_members ADD COLUMN IF NOT EXISTS hand_raised BOOLEAN DEFAULT false;
ALTER TABLE chatroom_members ADD COLUMN IF NOT EXISTS host_muted BOOLEAN DEFAULT false;   -- true = muted by host, cannot self-unmute

-- 3. chatroom_bans — ensure it exists for blocked user checks
CREATE TABLE IF NOT EXISTS chatroom_bans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL,
  user_id UUID NOT NULL,
  banned_by UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(room_id, user_id)
);
ALTER TABLE chatroom_bans ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "chatroom_bans_select" ON chatroom_bans FOR SELECT USING (true);
CREATE POLICY IF NOT EXISTS "chatroom_bans_insert" ON chatroom_bans FOR INSERT WITH CHECK (true);

-- 4. Reports table
CREATE TABLE IF NOT EXISTS chatroom_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL,
  reporter_id UUID NOT NULL,
  reported_user_id UUID NOT NULL,
  reason TEXT NOT NULL,   -- 'hate_speech', 'harassment', 'spam', 'inappropriate', 'other'
  details TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE chatroom_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "chatroom_reports_insert" ON chatroom_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- 5. Enable realtime for chatroom_bans
ALTER PUBLICATION supabase_realtime ADD TABLE chatroom_bans;
