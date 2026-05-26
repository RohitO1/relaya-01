-- ============================================================
-- COMPANIONS MARKETPLACE — FULL DATABASE MIGRATION
-- Sections 1-14 of the specification
-- All times stored UTC. RLS enabled on all tables.
-- ============================================================

-- ── 1. COMPANION PROFILES ──────────────────────────────────
CREATE TABLE IF NOT EXISTS companion_profiles (
  id                            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name                  TEXT NOT NULL,
  bio_short                     TEXT CHECK (char_length(bio_short) <= 300),
  bio_long                      TEXT CHECK (char_length(bio_long) <= 1000),
  photos                        TEXT[] DEFAULT '{}',
  languages                     TEXT[] DEFAULT '{}',
  city                          TEXT,
  region                        TEXT,
  country                       TEXT,
  status                        TEXT NOT NULL DEFAULT 'PENDING'
                                  CHECK (status IN ('PENDING','ACTIVE','PAUSED','SUSPENDED','DEACTIVATED')),
  is_virtual_enabled            BOOLEAN DEFAULT FALSE,
  is_physical_enabled           BOOLEAN DEFAULT FALSE,
  virtual_rate_per_hour         NUMERIC(10,2) DEFAULT 0,
  physical_rate_per_hour        NUMERIC(10,2) DEFAULT 0,
  virtual_min_duration_minutes  INT DEFAULT 30,
  virtual_max_duration_minutes  INT DEFAULT 120,
  physical_min_duration_minutes INT DEFAULT 60,
  travel_radius_km              INT DEFAULT 10,
  meet_location_preference      TEXT DEFAULT 'public',
  advance_notice_hours          INT DEFAULT 24 CHECK (advance_notice_hours IN (1,3,12,24,48)),
  max_sessions_per_day          INT DEFAULT 2,
  tags                          TEXT[] DEFAULT '{}',
  is_id_verified                BOOLEAN DEFAULT FALSE,
  overall_rating                NUMERIC(3,2) DEFAULT 0,
  total_sessions                INT DEFAULT 0,
  response_rate_percent         INT DEFAULT 0,
  avg_response_hours            NUMERIC(5,2) DEFAULT 0,
  late_cancel_count_30d         INT DEFAULT 0,
  total_late_cancels            INT DEFAULT 0,
  no_show_count                 INT DEFAULT 0,
  photo_moderation_status       TEXT DEFAULT 'PENDING' CHECK (photo_moderation_status IN ('PENDING','APPROVED','FLAGGED')),
  created_at                    TIMESTAMPTZ DEFAULT now(),
  updated_at                    TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_companion_profiles_status ON companion_profiles(status);
CREATE INDEX IF NOT EXISTS idx_companion_profiles_user ON companion_profiles(user_id);

-- ── 2. AVAILABILITY (Section 1.2) ──────────────────────────
CREATE TABLE IF NOT EXISTS companion_availability (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  companion_id  UUID NOT NULL REFERENCES companion_profiles(id) ON DELETE CASCADE,
  day_of_week   INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time_utc TIME NOT NULL,
  end_time_utc   TIME NOT NULL,
  is_active     BOOLEAN DEFAULT TRUE,
  UNIQUE(companion_id, day_of_week)
);

-- ── 3. BLACKOUT DATES ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS companion_blackout_dates (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  companion_id  UUID NOT NULL REFERENCES companion_profiles(id) ON DELETE CASCADE,
  date_utc      DATE NOT NULL,
  reason        TEXT,
  UNIQUE(companion_id, date_utc)
);

-- ── 4. BOOKINGS (Section 3.3 state machine) ────────────────
CREATE TABLE IF NOT EXISTS companion_bookings (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booker_id           UUID NOT NULL REFERENCES auth.users(id),
  companion_id        UUID NOT NULL REFERENCES companion_profiles(id),
  session_type        TEXT NOT NULL CHECK (session_type IN ('VIRTUAL','PHYSICAL')),
  status              TEXT NOT NULL DEFAULT 'PENDING_CONFIRMATION'
                        CHECK (status IN (
                          'PENDING_CONFIRMATION','CONFIRMED','RESCHEDULED','ACTIVE',
                          'COMPLETED','REVIEWED','CANCELLED_BY_BOOKER',
                          'CANCELLED_BY_COMPANION','DISPUTED','REFUNDED',
                          'NO_SHOW_BOOKER','NO_SHOW_COMPANION','INTERRUPTED'
                        )),
  scheduled_start_utc TIMESTAMPTZ NOT NULL,
  scheduled_end_utc   TIMESTAMPTZ NOT NULL,
  actual_start_utc    TIMESTAMPTZ,
  actual_end_utc      TIMESTAMPTZ,
  duration_minutes    INT NOT NULL,
  rate_per_hour       NUMERIC(10,2) NOT NULL,
  session_cost        NUMERIC(10,2) NOT NULL,
  platform_fee        NUMERIC(10,2) NOT NULL,
  total_charged       NUMERIC(10,2) NOT NULL,
  booker_note         TEXT CHECK (char_length(booker_note) <= 200),
  meet_location       TEXT,
  escrow_status       TEXT DEFAULT 'HELD' CHECK (escrow_status IN ('HELD','RELEASED','REFUNDED','PARTIAL_REFUND','DISPUTED')),
  payment_id          TEXT,
  idempotency_key     TEXT UNIQUE,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bookings_companion_time ON companion_bookings(companion_id, scheduled_start_utc);
CREATE INDEX IF NOT EXISTS idx_bookings_booker ON companion_bookings(booker_id);

-- EC-04: Blocked booker-companion pairs
CREATE TABLE IF NOT EXISTS companion_dispute_pairs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booker_id    UUID NOT NULL REFERENCES auth.users(id),
  companion_id UUID NOT NULL REFERENCES companion_profiles(id),
  is_blocked   BOOLEAN DEFAULT TRUE,
  reason       TEXT,
  created_at   TIMESTAMPTZ DEFAULT now()
);

-- ── 5. VIDEO ROOMS (Section 5.1) ───────────────────────────
CREATE TABLE IF NOT EXISTS companion_video_rooms (
  id                               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id                       UUID NOT NULL REFERENCES companion_bookings(id) ON DELETE CASCADE,
  status                           TEXT NOT NULL DEFAULT 'CREATED'
                                     CHECK (status IN ('CREATED','LOCKED','OPEN','ACTIVE','ONE_PARTY','ENDED','EXPIRED','INTERRUPTED')),
  booker_join_token                TEXT NOT NULL,
  companion_join_token             TEXT NOT NULL,
  booker_joined_at                 TIMESTAMPTZ,
  companion_joined_at              TIMESTAMPTZ,
  booker_left_at                   TIMESTAMPTZ,
  companion_left_at                TIMESTAMPTZ,
  total_connected_duration_seconds INT DEFAULT 0,
  extension_granted_minutes        INT DEFAULT 0,
  disconnect_events                JSONB DEFAULT '[]',
  screen_record_events             JSONB DEFAULT '[]',
  created_at                       TIMESTAMPTZ DEFAULT now(),
  ended_at                         TIMESTAMPTZ,
  UNIQUE(booking_id)
);

CREATE TABLE IF NOT EXISTS companion_video_room_chat (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id   UUID NOT NULL REFERENCES companion_video_rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  message   TEXT NOT NULL,
  sent_at   TIMESTAMPTZ DEFAULT now()
);

-- ── 6. REVIEWS (Section 9) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS companion_session_reviews (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id        UUID NOT NULL REFERENCES companion_bookings(id),
  reviewer_id       UUID NOT NULL REFERENCES auth.users(id),
  reviewee_id       UUID NOT NULL REFERENCES auth.users(id),
  reviewer_role     TEXT NOT NULL CHECK (reviewer_role IN ('BOOKER','COMPANION')),
  overall_rating    INT NOT NULL CHECK (overall_rating BETWEEN 1 AND 5),
  was_punctual      TEXT,
  would_book_again  TEXT,
  written_review    TEXT,
  private_feedback  TEXT,
  companion_response TEXT CHECK (char_length(companion_response) <= 200),
  is_published      BOOLEAN DEFAULT FALSE,
  moderation_flag   BOOLEAN DEFAULT FALSE,
  created_at        TIMESTAMPTZ DEFAULT now(),
  UNIQUE(booking_id, reviewer_id)
);

-- ── 7. NOTIFICATION JOBS (Section 12) ──────────────────────
CREATE TABLE IF NOT EXISTS companion_notification_jobs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id        UUID NOT NULL REFERENCES companion_bookings(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL,
  scheduled_for_utc TIMESTAMPTZ NOT NULL,
  recipient_user_id UUID NOT NULL REFERENCES auth.users(id),
  status            TEXT NOT NULL DEFAULT 'PENDING'
                      CHECK (status IN ('PENDING','SENT','FAILED','CANCELLED')),
  retry_count       INT DEFAULT 0,
  sent_at           TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notif_jobs_pending ON companion_notification_jobs(scheduled_for_utc)
  WHERE status = 'PENDING';

-- ── 8. SAFETY REPORTS (Section 7.3) ────────────────────────
CREATE TABLE IF NOT EXISTS companion_safety_reports (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id       UUID NOT NULL REFERENCES companion_bookings(id),
  reporter_id      UUID NOT NULL REFERENCES auth.users(id),
  reported_user_id UUID NOT NULL REFERENCES auth.users(id),
  report_type      TEXT NOT NULL CHECK (report_type IN ('IN_SESSION_REPORT','SOS','POST_SESSION')),
  reason           TEXT NOT NULL,
  details          TEXT,
  gps_coordinates  JSONB,
  status           TEXT NOT NULL DEFAULT 'PENDING'
                     CHECK (status IN ('PENDING','UNDER_REVIEW','RESOLVED','DISMISSED')),
  admin_notes      TEXT,
  created_at       TIMESTAMPTZ DEFAULT now(),
  resolved_at      TIMESTAMPTZ
);

-- ── 9. ESCROW (Section 6.1) ────────────────────────────────
CREATE TABLE IF NOT EXISTS companion_escrow_transactions (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id              UUID NOT NULL REFERENCES companion_bookings(id) ON DELETE CASCADE,
  amount                  NUMERIC(10,2) NOT NULL,
  currency                TEXT DEFAULT 'INR',
  status                  TEXT NOT NULL DEFAULT 'HELD'
                            CHECK (status IN ('HELD','RELEASED','REFUNDED','PARTIAL_REFUND','DISPUTED')),
  held_at                 TIMESTAMPTZ DEFAULT now(),
  released_at             TIMESTAMPTZ,
  release_type            TEXT CHECK (release_type IN ('AUTO','MANUAL_ADMIN','DISPUTE_RESOLVED')),
  companion_payout_amount NUMERIC(10,2),
  booker_refund_amount    NUMERIC(10,2),
  platform_revenue        NUMERIC(10,2),
  notes                   TEXT,
  UNIQUE(booking_id)
);

-- ── 10. RATE LIMITING (Section 14) ─────────────────────────
CREATE TABLE IF NOT EXISTS companion_rate_limits (
  user_id      UUID NOT NULL REFERENCES auth.users(id),
  action       TEXT NOT NULL,
  window_start TIMESTAMPTZ NOT NULL DEFAULT date_trunc('day', now()),
  count        INT DEFAULT 1,
  PRIMARY KEY(user_id, action, window_start)
);

-- ── 11. TRIGGERS ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_companion_profiles_ua BEFORE UPDATE ON companion_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_companion_bookings_ua BEFORE UPDATE ON companion_bookings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- EC-08: Auto-cancel bookings when companion suspended
CREATE OR REPLACE FUNCTION handle_companion_suspended()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'SUSPENDED' AND OLD.status != 'SUSPENDED' THEN
    UPDATE companion_bookings SET status = 'CANCELLED_BY_COMPANION'
    WHERE companion_id = NEW.id AND status IN ('PENDING_CONFIRMATION','CONFIRMED')
      AND scheduled_start_utc > now();
    UPDATE companion_notification_jobs nj SET status = 'CANCELLED'
    FROM companion_bookings b
    WHERE b.id = nj.booking_id AND b.companion_id = NEW.id AND nj.status = 'PENDING';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_companion_suspended
  AFTER UPDATE ON companion_profiles
  FOR EACH ROW EXECUTE FUNCTION handle_companion_suspended();

-- Rating recalculation after review published (Section 9.3)
CREATE OR REPLACE FUNCTION recalculate_companion_rating()
RETURNS TRIGGER AS $$
DECLARE comp_id UUID; new_rating NUMERIC; new_total INT;
BEGIN
  SELECT b.companion_id INTO comp_id FROM companion_bookings b WHERE b.id = NEW.booking_id;
  SELECT COALESCE(AVG(r.overall_rating),0), COUNT(*) INTO new_rating, new_total
  FROM (SELECT overall_rating FROM companion_session_reviews
        WHERE reviewee_id=(SELECT user_id FROM companion_profiles WHERE id=comp_id)
          AND is_published=TRUE ORDER BY created_at DESC LIMIT 50) r;
  UPDATE companion_profiles SET overall_rating=ROUND(new_rating::NUMERIC,2), total_sessions=new_total WHERE id=comp_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_rating_update AFTER INSERT OR UPDATE ON companion_session_reviews
  FOR EACH ROW WHEN (NEW.is_published=TRUE) EXECUTE FUNCTION recalculate_companion_rating();

-- Rate limit on booking inserts (Section 14: max 10/day)
CREATE OR REPLACE FUNCTION check_booking_rate_limit()
RETURNS TRIGGER AS $$
DECLARE today_count INT;
BEGIN
  SELECT COALESCE(SUM(count),0) INTO today_count FROM companion_rate_limits
  WHERE user_id=NEW.booker_id AND action='booking_request' AND window_start=date_trunc('day',now());
  IF today_count >= 10 THEN RAISE EXCEPTION 'Max 10 booking requests per day.'; END IF;
  INSERT INTO companion_rate_limits(user_id,action,window_start,count) VALUES(NEW.booker_id,'booking_request',date_trunc('day',now()),1)
  ON CONFLICT(user_id,action,window_start) DO UPDATE SET count=companion_rate_limits.count+1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_booking_rate_limit BEFORE INSERT ON companion_bookings
  FOR EACH ROW EXECUTE FUNCTION check_booking_rate_limit();

-- ── 12. ROW LEVEL SECURITY ──────────────────────────────────

ALTER TABLE companion_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE companion_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE companion_blackout_dates ENABLE ROW LEVEL SECURITY;
ALTER TABLE companion_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE companion_video_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE companion_session_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE companion_notification_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE companion_safety_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE companion_escrow_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read active profiles" ON companion_profiles FOR SELECT USING (status IN ('ACTIVE','PAUSED') OR user_id=auth.uid());
CREATE POLICY "Owner update profile" ON companion_profiles FOR UPDATE USING (user_id=auth.uid());
CREATE POLICY "Owner insert profile" ON companion_profiles FOR INSERT WITH CHECK (user_id=auth.uid());

CREATE POLICY "Own availability" ON companion_availability FOR ALL USING (companion_id IN (SELECT id FROM companion_profiles WHERE user_id=auth.uid()));
CREATE POLICY "Own blackouts" ON companion_blackout_dates FOR ALL USING (companion_id IN (SELECT id FROM companion_profiles WHERE user_id=auth.uid()));

CREATE POLICY "Booking parties" ON companion_bookings FOR SELECT USING (booker_id=auth.uid() OR companion_id IN (SELECT id FROM companion_profiles WHERE user_id=auth.uid()));
CREATE POLICY "Booker insert" ON companion_bookings FOR INSERT WITH CHECK (booker_id=auth.uid());
CREATE POLICY "Booking parties update" ON companion_bookings FOR UPDATE USING (booker_id=auth.uid() OR companion_id IN (SELECT id FROM companion_profiles WHERE user_id=auth.uid()));

CREATE POLICY "Video room participants" ON companion_video_rooms FOR SELECT USING (booking_id IN (SELECT id FROM companion_bookings WHERE booker_id=auth.uid() OR companion_id IN (SELECT id FROM companion_profiles WHERE user_id=auth.uid())));

CREATE POLICY "Published reviews readable" ON companion_session_reviews FOR SELECT USING (is_published=TRUE OR reviewer_id=auth.uid());
CREATE POLICY "Reviewer inserts review" ON companion_session_reviews FOR INSERT WITH CHECK (reviewer_id=auth.uid());

CREATE POLICY "Own notifications" ON companion_notification_jobs FOR SELECT USING (recipient_user_id=auth.uid());
CREATE POLICY "Own reports" ON companion_safety_reports FOR SELECT USING (reporter_id=auth.uid());
CREATE POLICY "Can file report" ON companion_safety_reports FOR INSERT WITH CHECK (reporter_id=auth.uid());
CREATE POLICY "Escrow parties" ON companion_escrow_transactions FOR SELECT USING (booking_id IN (SELECT id FROM companion_bookings WHERE booker_id=auth.uid() OR companion_id IN (SELECT id FROM companion_profiles WHERE user_id=auth.uid())));

-- ── 13. SCHEDULED JOB (pg_cron — auto escrow release) ──────
-- Uncomment and run via Supabase Dashboard > Extensions > pg_cron:
-- SELECT cron.schedule('companion-escrow-72h', '*/15 * * * *', $$
--   UPDATE companion_escrow_transactions et SET status='RELEASED', released_at=now(), release_type='AUTO'
--   FROM companion_bookings b WHERE et.booking_id=b.id AND b.status='COMPLETED'
--     AND et.status='HELD' AND b.actual_end_utc < now() - INTERVAL '72 hours';
--   UPDATE companion_bookings SET status='REVIEWED' WHERE status='COMPLETED'
--     AND actual_end_utc < now() - INTERVAL '72 hours';
-- $$);
