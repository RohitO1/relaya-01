-- ============================================================
-- Meetra: Separate post_likes and post_comments tables
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. post_likes table
CREATE TABLE IF NOT EXISTS post_likes (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id     TEXT NOT NULL,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- 2. post_comments table
CREATE TABLE IF NOT EXISTS post_comments (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id     TEXT NOT NULL,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_name   TEXT DEFAULT 'Anonymous',
  avatar_url  TEXT DEFAULT '',
  text        TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Enable RLS
ALTER TABLE post_likes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies: post_likes
CREATE POLICY "Anyone can view likes"   ON post_likes FOR SELECT USING (true);
CREATE POLICY "Users can like posts"    ON post_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unlike posts"  ON post_likes FOR DELETE USING (auth.uid() = user_id);

-- 5. RLS Policies: post_comments
CREATE POLICY "Anyone can view comments"     ON post_comments FOR SELECT USING (true);
CREATE POLICY "Users can add comments"       ON post_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own comments" ON post_comments FOR DELETE USING (auth.uid() = user_id);

-- 6. Enable Realtime on both tables
ALTER PUBLICATION supabase_realtime ADD TABLE post_likes;
ALTER PUBLICATION supabase_realtime ADD TABLE post_comments;

-- 7. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id    ON post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id    ON post_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_post_id ON post_comments(post_id);
