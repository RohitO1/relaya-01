-- ==============================================================================
-- PHASE 1: MESSAGING OVERHAUL SCHEMA UPDATES
-- ==============================================================================

-- 1. user_chat_settings
-- Tracks user-specific settings for a conversation with a specific partner.
-- Since the current schema uses sender_id/receiver_id directly, we map settings
-- using (user_id, partner_id). For group chats, partner_id will be the activity/group ID.
CREATE TABLE IF NOT EXISTS public.user_chat_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    partner_id TEXT NOT NULL, -- UUID for DM, String for groups/activities
    is_pinned BOOLEAN DEFAULT false,
    is_muted BOOLEAN DEFAULT false,
    is_archived BOOLEAN DEFAULT false,
    is_manually_unread BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, partner_id)
);

-- 2. message_reactions
-- Tracks emoji reactions on specific messages
CREATE TABLE IF NOT EXISTS public.message_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id BIGINT NOT NULL, -- Assuming messages table uses BIGSERIAL or BIGINT
    user_id UUID NOT NULL,
    emoji TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(message_id, user_id, emoji)
);

-- 3. deleted_messages
-- Tracks which messages a user has soft-deleted for themselves ("Delete for me")
CREATE TABLE IF NOT EXISTS public.deleted_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id BIGINT NOT NULL,
    user_id UUID NOT NULL,
    deleted_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(message_id, user_id)
);

-- 4. Update messages table
-- Add columns for features requested in the prompt
ALTER TABLE public.messages
    ADD COLUMN IF NOT EXISTS reply_to_id BIGINT,
    ADD COLUMN IF NOT EXISTS is_forwarded BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS is_deleted_for_everyone BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS is_view_once BOOLEAN DEFAULT false;

-- RLS Policies (Ensure they exist and are secure)
ALTER TABLE public.user_chat_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own chat settings" 
    ON public.user_chat_settings FOR ALL 
    USING (auth.uid() = user_id);

ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read all reactions" 
    ON public.message_reactions FOR SELECT 
    USING (true);
CREATE POLICY "Users can insert their own reactions" 
    ON public.message_reactions FOR INSERT 
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own reactions" 
    ON public.message_reactions FOR DELETE 
    USING (auth.uid() = user_id);

ALTER TABLE public.deleted_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can see their own deleted messages" 
    ON public.deleted_messages FOR ALL 
    USING (auth.uid() = user_id);
