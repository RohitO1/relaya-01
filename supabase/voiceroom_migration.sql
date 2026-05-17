-- VOICEROOM MIGRATION — Run in Supabase SQL Editor

-- 1. Add missing columns to chatrooms table
ALTER TABLE chatrooms
  ADD COLUMN IF NOT EXISTS co_host_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS tags TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS peak_listeners INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_participants INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS room_started_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS room_ended_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS host_last_seen TIMESTAMPTZ DEFAULT now();

-- 2. Add missing columns to chatroom_members
ALTER TABLE chatroom_members
  ADD COLUMN IF NOT EXISTS is_cohost BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS host_muted BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS hand_raised BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS mic_requested BOOLEAN DEFAULT false;

-- 3. Reports table
CREATE TABLE IF NOT EXISTS chatroom_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id TEXT NOT NULL,
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE chatroom_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "reports_insert" ON chatroom_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "reports_select_own" ON chatroom_reports FOR SELECT USING (auth.uid() = reporter_id);

-- 4. Reminders table (for scheduled rooms)
CREATE TABLE IF NOT EXISTS chatroom_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id TEXT NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(room_id, user_id)
);
ALTER TABLE chatroom_reminders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "reminders_all" ON chatroom_reminders FOR ALL USING (auth.uid() = user_id);

-- 5. Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE chatrooms;
ALTER PUBLICATION supabase_realtime ADD TABLE chatroom_members;
ALTER PUBLICATION supabase_realtime ADD TABLE chatroom_messages;
