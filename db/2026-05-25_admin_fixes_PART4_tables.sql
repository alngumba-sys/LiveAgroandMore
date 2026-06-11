-- ═══════════════════════════════════════════════════════════════════
-- PART 4 of 4 — New tables (app_sessions, hire_bookings)
-- Run last.
-- ═══════════════════════════════════════════════════════════════════

SET row_security = off;

-- ── app_sessions (DAU tracking) ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS app_sessions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES app_users(id),
  device      text,
  app_version text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_app_sessions_created ON app_sessions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_sessions_user_id ON app_sessions(user_id);

ALTER TABLE app_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_sessions_insert_any" ON app_sessions;
CREATE POLICY "app_sessions_insert_any" ON app_sessions
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "staff_read_all" ON app_sessions;
CREATE POLICY "staff_read_all" ON app_sessions
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- ── hire_bookings (For Hire bookings tab) ───────────────────────────
CREATE TABLE IF NOT EXISTS hire_bookings (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_number   text UNIQUE NOT NULL,
  farmer_id        uuid REFERENCES app_users(id),
  farmer_name      text NOT NULL,
  farmer_phone     text NOT NULL,
  provider_id      uuid REFERENCES hire_providers(id),
  provider_name    text,
  equipment_type   text,
  district         text,
  requested_date   date,
  status           text NOT NULL DEFAULT 'pending',
  notes            text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_hire_bookings_status   ON hire_bookings(status);
CREATE INDEX IF NOT EXISTS idx_hire_bookings_provider ON hire_bookings(provider_id);

ALTER TABLE hire_bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff_read_all" ON hire_bookings;
CREATE POLICY "staff_read_all" ON hire_bookings FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "staff_write"    ON hire_bookings;
CREATE POLICY "staff_write"    ON hire_bookings FOR ALL    USING (auth.uid() IS NOT NULL);

-- Sequence + trigger for HB-YYYY-NNNNN
CREATE SEQUENCE IF NOT EXISTS hire_booking_seq START 1;

CREATE OR REPLACE FUNCTION generate_hire_booking_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.booking_number IS NULL OR NEW.booking_number = '' THEN
    NEW.booking_number := 'HB-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(CAST(nextval('hire_booking_seq') AS text), 5, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_hire_booking_number ON hire_bookings;
CREATE TRIGGER set_hire_booking_number BEFORE INSERT ON hire_bookings
  FOR EACH ROW EXECUTE PROCEDURE generate_hire_booking_number();

SET row_security = on;

-- Verify
SELECT 'app_sessions',  (SELECT count(*) FROM information_schema.tables WHERE table_name='app_sessions')
UNION ALL SELECT 'hire_bookings', (SELECT count(*) FROM information_schema.tables WHERE table_name='hire_bookings');
