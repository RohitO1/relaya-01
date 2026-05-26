-- Add dob column to profiles table if it does not exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS dob TEXT;
