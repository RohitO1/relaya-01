-- ============================================================
-- BOLROOM ECOSYSTEM — Database Migration
-- Run this in Supabase SQL Editor (Dashboard → SQL → New Query)
-- ============================================================

-- 1. Anonymous Profiles
CREATE TABLE IF NOT EXISTS bolroom_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  anon_name TEXT NOT NULL DEFAULT 'Anonymous',
  anon_bio TEXT DEFAULT '',
  avatar_key TEXT DEFAULT 'default',          -- preset avatar identifier
  custom_avatar_url TEXT DEFAULT '',           -- user-uploaded avatar
  aura_color TEXT DEFAULT '#7856FF',           -- hex color for profile glow
  voice_modulator TEXT DEFAULT 'None',         -- voice effect name
  hide_online_status BOOLEAN DEFAULT false,
  rooms_hosted INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE bolroom_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "bolroom_profiles_select" ON bolroom_profiles FOR SELECT USING (true);
CREATE POLICY "bolroom_profiles_insert" ON bolroom_profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "bolroom_profiles_update" ON bolroom_profiles FOR UPDATE USING (auth.uid() = id);

-- 2. Follows
CREATE TABLE IF NOT EXISTS bolroom_follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(follower_id, following_id)
);
ALTER TABLE bolroom_follows ENABLE ROW LEVEL SECURITY;
CREATE POLICY "bolroom_follows_select" ON bolroom_follows FOR SELECT USING (true);
CREATE POLICY "bolroom_follows_insert" ON bolroom_follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "bolroom_follows_delete" ON bolroom_follows FOR DELETE USING (auth.uid() = follower_id);

-- 3. Communities
CREATE TABLE IF NOT EXISTS bolroom_communities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  icon TEXT DEFAULT '💬',
  category TEXT DEFAULT 'General',
  banner_color TEXT DEFAULT '#7856FF',
  rules TEXT DEFAULT '',
  creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  member_count INTEGER DEFAULT 1,
  is_private BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE bolroom_communities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "bolroom_communities_select" ON bolroom_communities FOR SELECT USING (true);
CREATE POLICY "bolroom_communities_insert" ON bolroom_communities FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "bolroom_communities_update" ON bolroom_communities FOR UPDATE USING (auth.uid() = creator_id);
CREATE POLICY "bolroom_communities_delete" ON bolroom_communities FOR DELETE USING (auth.uid() = creator_id);

-- 4. Community Members
CREATE TABLE IF NOT EXISTS bolroom_community_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES bolroom_communities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'member',  -- 'member', 'moderator', 'admin'
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(community_id, user_id)
);
ALTER TABLE bolroom_community_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "bcm_select" ON bolroom_community_members FOR SELECT USING (true);
CREATE POLICY "bcm_insert" ON bolroom_community_members FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "bcm_delete" ON bolroom_community_members FOR DELETE USING (auth.uid() = user_id);

-- 5. Community Messages
CREATE TABLE IF NOT EXISTS bolroom_community_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES bolroom_communities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anon_name TEXT DEFAULT 'Anonymous',
  avatar_key TEXT DEFAULT 'default',
  text TEXT NOT NULL,
  image_url TEXT,
  is_pinned BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE bolroom_community_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "bcmsg_select" ON bolroom_community_messages FOR SELECT USING (true);
CREATE POLICY "bcmsg_insert" ON bolroom_community_messages FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 6. DM Conversations
CREATE TABLE IF NOT EXISTS bolroom_dm_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user1_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user2_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  last_message TEXT DEFAULT '',
  last_message_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user1_id, user2_id)
);
ALTER TABLE bolroom_dm_conversations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "bdm_select" ON bolroom_dm_conversations FOR SELECT USING (auth.uid() = user1_id OR auth.uid() = user2_id);
CREATE POLICY "bdm_insert" ON bolroom_dm_conversations FOR INSERT WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);
CREATE POLICY "bdm_update" ON bolroom_dm_conversations FOR UPDATE USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- 7. DM Messages
CREATE TABLE IF NOT EXISTS bolroom_dm_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES bolroom_dm_conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  image_url TEXT,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE bolroom_dm_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "bdmsg_select" ON bolroom_dm_messages FOR SELECT USING (
  EXISTS (SELECT 1 FROM bolroom_dm_conversations c WHERE c.id = conversation_id AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid()))
);
CREATE POLICY "bdmsg_insert" ON bolroom_dm_messages FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "bdmsg_update" ON bolroom_dm_messages FOR UPDATE USING (
  EXISTS (SELECT 1 FROM bolroom_dm_conversations c WHERE c.id = conversation_id AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid()))
);

-- Realtime: enable for all bolroom tables
ALTER PUBLICATION supabase_realtime ADD TABLE bolroom_community_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE bolroom_dm_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE bolroom_dm_conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE bolroom_community_members;
ALTER PUBLICATION supabase_realtime ADD TABLE bolroom_follows;

-- ═══════════════════════════════════════════════════════════════
-- VOICEROOM — Additional Tables & Columns
-- ═══════════════════════════════════════════════════════════════

-- 8. Reports (in-room user reports)
CREATE TABLE IF NOT EXISTS chatroom_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id TEXT NOT NULL,
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL DEFAULT 'Other',
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE chatroom_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "chatroom_reports_insert" ON chatroom_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "chatroom_reports_select" ON chatroom_reports FOR SELECT USING (auth.uid() = reporter_id);

-- 9. Scheduled Room Reminders
CREATE TABLE IF NOT EXISTS chatroom_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  room_id TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, room_id)
);
ALTER TABLE chatroom_reminders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "chatroom_reminders_insert" ON chatroom_reminders FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "chatroom_reminders_select" ON chatroom_reminders FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "chatroom_reminders_delete" ON chatroom_reminders FOR DELETE USING (auth.uid() = user_id);

-- 10. Add voiceroom columns to chatrooms (run as ALTER if table already exists)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chatrooms' AND column_name='co_host_id') THEN
    ALTER TABLE chatrooms ADD COLUMN co_host_id UUID REFERENCES auth.users(id);
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
END $$;
