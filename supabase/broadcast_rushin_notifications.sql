-- ============================================================
-- FIX: Missing column 'notification_settings' in 'profiles'
-- ============================================================

-- 1. Add the missing column that the Dart code expects
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS notification_settings JSONB DEFAULT '{"nearby_activities": true}'::jsonb;

-- ============================================================
-- RPC for Broadcasting Notifications to Nearby Users
-- SECURITY DEFINER bypasses RLS so we can insert for others
-- ============================================================

CREATE OR REPLACE FUNCTION public.broadcast_nearby_notifications(
  p_creator_id UUID,
  p_activity_id UUID,
  p_title TEXT,
  p_body TEXT,
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION,
  p_type TEXT,
  p_payload JSONB
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_dlat DOUBLE PRECISION;
  v_dlng DOUBLE PRECISION;
  v_a DOUBLE PRECISION;
  v_c DOUBLE PRECISION;
  v_dist DOUBLE PRECISION;
  v_lat1 DOUBLE PRECISION;
  v_lat2 DOUBLE PRECISION;
BEGIN
  v_lat1 := radians(p_lat);
  
  FOR v_user IN 
    SELECT id, lat, lng, notification_settings 
    FROM public.profiles 
    WHERE id != p_creator_id
  LOOP
    -- Check notification settings if nearby_activities is false
    IF v_user.notification_settings IS NOT NULL AND (v_user.notification_settings->>'nearby_activities') = 'false' THEN
      CONTINUE;
    END IF;

    IF v_user.lat IS NOT NULL AND v_user.lng IS NOT NULL THEN
      -- Haversine formula
      v_lat2 := radians(v_user.lat);
      v_dlat := radians(v_user.lat - p_lat);
      v_dlng := radians(v_user.lng - p_lng);
      
      v_a := sin(v_dlat / 2.0) * sin(v_dlat / 2.0) +
             cos(v_lat1) * cos(v_lat2) * 
             sin(v_dlng / 2.0) * sin(v_dlng / 2.0);
             
      v_c := 2.0 * asin(sqrt(abs(v_a))); -- using abs() to prevent floating point inaccuracies causing NaN
      v_dist := 6371.0 * v_c;

      IF v_dist <= p_radius_km THEN
        INSERT INTO public.notifications (user_id, type, title, body, payload, is_read, created_at)
        VALUES (v_user.id, p_type, p_title, p_body, p_payload, false, now());
      END IF;
    END IF;
  END LOOP;
END;
$$;
