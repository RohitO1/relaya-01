ALTER TABLE text_camps
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

ALTER TABLE text_camp_members
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'member';

CREATE TABLE IF NOT EXISTS text_camp_bans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    camp_id UUID REFERENCES text_camps(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    banned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    banned_by UUID REFERENCES profiles(id),
    reason TEXT,
    UNIQUE(camp_id, user_id)
);

ALTER TABLE text_camp_bans ENABLE ROW LEVEL SECURITY;

-- Minimal permissive policies for development (application-level enforcement will be added)
CREATE POLICY "Allow read text_camp_bans" ON text_camp_bans FOR SELECT USING (true);
CREATE POLICY "Allow insert text_camp_bans" ON text_camp_bans FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow delete text_camp_bans" ON text_camp_bans FOR DELETE USING (true);

NOTIFY pgrst, 'reload schema';
