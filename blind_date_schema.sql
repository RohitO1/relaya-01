CREATE TABLE IF NOT EXISTS bolroom_blind_date_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL,
    host_user_id UUID NOT NULL,
    player_1_user_id UUID NOT NULL,
    player_2_user_id UUID NOT NULL,
    player_1_gender TEXT,
    player_2_gender TEXT,
    state TEXT NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    session_ended_at TIMESTAMP WITH TIME ZONE,
    session_end_reason TEXT,
    session_duration_seconds INTEGER,
    poll_opened_at TIMESTAMP WITH TIME ZONE,
    poll_closed_at TIMESTAMP WITH TIME ZONE,
    transcript TEXT,
    analysis_json JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS bolroom_blind_date_votes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES bolroom_blind_date_sessions(id) ON DELETE CASCADE,
    voter_user_id UUID NOT NULL,
    vote_choice TEXT NOT NULL,
    voter_role TEXT NOT NULL,
    voted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ensure gender field exists on bolroom_profiles if it doesn't already
ALTER TABLE bolroom_profiles ADD COLUMN IF NOT EXISTS gender TEXT;
