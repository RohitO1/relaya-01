-- Create RPC function to reset password by phone number
-- Copy and execute this script inside your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/_/sql/new

CREATE OR REPLACE FUNCTION public.reset_user_password(phone_input text, new_password text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_id uuid;
  hashed_password text;
  possible_phone_1 text;
  possible_phone_2 text;
  possible_phone_3 text;
BEGIN
  -- Normalize phone numbers for search
  possible_phone_1 := phone_input; -- e.g., +917905761080
  possible_phone_2 := regexp_replace(phone_input, '[^0-9]', '', 'g'); -- e.g., 917905761080
  
  IF substring(possible_phone_2 from 1 for 2) = '91' AND length(possible_phone_2) > 10 THEN
    possible_phone_3 := substring(possible_phone_2 from 3); -- e.g., 7905761080
  ELSE
    possible_phone_3 := possible_phone_2;
  END IF;

  -- Find user ID in profiles
  SELECT id INTO user_id 
  FROM public.profiles 
  WHERE phone = possible_phone_1 
     OR phone = possible_phone_2 
     OR phone = possible_phone_3 
  LIMIT 1;
  
  IF user_id IS NULL THEN
    RETURN false;
  END IF;

  -- Hash new password using bcrypt (standard in Supabase auth)
  BEGIN
    hashed_password := extensions.crypt(new_password, extensions.gen_salt('bf'));
  EXCEPTION WHEN OTHERS THEN
    hashed_password := crypt(new_password, gen_salt('bf'));
  END;

  -- Update auth.users
  UPDATE auth.users 
  SET encrypted_password = hashed_password,
      updated_at = now()
  WHERE id = user_id;

  RETURN true;
END;
$$;
