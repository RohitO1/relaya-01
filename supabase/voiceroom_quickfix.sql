-- ═══════════════════════════════════════════════════════════════
-- VOICEROOM QUICK FIX — Run in Supabase SQL Editor NOW
-- Adds all missing columns to chatrooms + chatroom_members
-- Safe to run multiple times (uses IF NOT EXISTS)
-- ═══════════════════════════════════════════════════════════════

-- ── chatrooms table: missing columns ──
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatrooms' AND column_name='max_participants') THEN
    ALTER TABLE chatrooms ADD COLUMN max_participants INTEGER DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatrooms' AND column_name='visibility') THEN
    ALTER TABLE chatrooms ADD COLUMN visibility TEXT DEFAULT 'public';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatrooms' AND column_name='room_status') THEN
    ALTER TABLE chatrooms ADD COLUMN room_status TEXT DEFAULT 'active';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatrooms' AND column_name='scheduled_at') THEN
    ALTER TABLE chatrooms ADD COLUMN scheduled_at TIMESTAMPTZ;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatrooms' AND column_name='host_avatar') THEN
    ALTER TABLE chatrooms ADD COLUMN host_avatar TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatrooms' AND column_name='speak_permission') THEN
    ALTER TABLE chatrooms ADD COLUMN speak_permission TEXT DEFAULT 'everyone';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatrooms' AND column_name='is_recording') THEN
    ALTER TABLE chatrooms ADD COLUMN is_recording BOOLEAN DEFAULT false;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatrooms' AND column_name='pinned_post') THEN
    ALTER TABLE chatrooms ADD COLUMN pinned_post TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatrooms' AND column_name='co_host_id') THEN
    ALTER TABLE chatrooms ADD COLUMN co_host_id UUID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatrooms' AND column_name='tags') THEN
    ALTER TABLE chatrooms ADD COLUMN tags TEXT[] DEFAULT '{}';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatrooms' AND column_name='peak_listeners') THEN
    ALTER TABLE chatrooms ADD COLUMN peak_listeners INTEGER DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatrooms' AND column_name='total_participants') THEN
    ALTER TABLE chatrooms ADD COLUMN total_participants INTEGER DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatrooms' AND column_name='room_started_at') THEN
    ALTER TABLE chatrooms ADD COLUMN room_started_at TIMESTAMPTZ DEFAULT now();
  END IF;
END $$;

-- ── chatroom_members table: missing columns ──
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatroom_members' AND column_name='is_cohost') THEN
    ALTER TABLE chatroom_members ADD COLUMN is_cohost BOOLEAN DEFAULT false;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatroom_members' AND column_name='mic_requested') THEN
    ALTER TABLE chatroom_members ADD COLUMN mic_requested BOOLEAN DEFAULT false;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatroom_members' AND column_name='host_muted') THEN
    ALTER TABLE chatroom_members ADD COLUMN host_muted BOOLEAN DEFAULT false;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatroom_members' AND column_name='hand_raised') THEN
    ALTER TABLE chatroom_members ADD COLUMN hand_raised BOOLEAN DEFAULT false;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatroom_members' AND column_name='is_speaker') THEN
    ALTER TABLE chatroom_members ADD COLUMN is_speaker BOOLEAN DEFAULT false;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatroom_members' AND column_name='is_muted') THEN
    ALTER TABLE chatroom_members ADD COLUMN is_muted BOOLEAN DEFAULT true;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatroom_members' AND column_name='avatar_url') THEN
    ALTER TABLE chatroom_members ADD COLUMN avatar_url TEXT;
  END IF;
END $$;

-- ── Missing tables ──
CREATE TABLE IF NOT EXISTS chatroom_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id TEXT NOT NULL,
  reporter_id UUID NOT NULL,
  reported_user_id UUID NOT NULL,
  reason TEXT NOT NULL DEFAULT 'Other',
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE chatroom_reports ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='chatroom_reports' AND policyname='chatroom_reports_insert') THEN
    CREATE POLICY "chatroom_reports_insert" ON chatroom_reports FOR INSERT WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='chatroom_reports' AND policyname='chatroom_reports_select') THEN
    CREATE POLICY "chatroom_reports_select" ON chatroom_reports FOR SELECT USING (true);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS chatroom_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  room_id TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, room_id)
);
ALTER TABLE chatroom_reminders ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='chatroom_reminders' AND policyname='chatroom_reminders_all') THEN
    CREATE POLICY "chatroom_reminders_all" ON chatroom_reminders FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS chatroom_bans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id TEXT NOT NULL,
  user_id UUID NOT NULL,
  banned_by UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(room_id, user_id)
);
ALTER TABLE chatroom_bans ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='chatroom_bans' AND policyname='chatroom_bans_all') THEN
    CREATE POLICY "chatroom_bans_all" ON chatroom_bans FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;
