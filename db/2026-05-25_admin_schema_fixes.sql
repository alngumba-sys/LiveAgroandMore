-- ═══════════════════════════════════════════════════════════════════
-- AGRO AND MORE — Admin platform schema fixes (2026-05-25)
--
-- Adds missing enum values, columns, and tables that the admin SPA
-- references but the original schema.sql doesn't define. Run AFTER the
-- demo-data wipe, in the Supabase SQL Editor.
--
-- Safe to run more than once (uses IF NOT EXISTS / ADD VALUE IF NOT EXISTS).
-- ═══════════════════════════════════════════════════════════════════

SET row_security = off;

-- ─── 1) ENUM ADDITIONS ──────────────────────────────────────────────
-- 'finance' role used by Sandra's staff seat + STAFF_ROLES const
ALTER TYPE staff_role  ADD VALUE IF NOT EXISTS 'finance';
-- 'rejected' status used by decideOfficer / rejectOfficer
ALTER TYPE user_status ADD VALUE IF NOT EXISTS 'rejected';

-- ─── 2) app_users — missing columns (B17) ───────────────────────────
ALTER TABLE app_users
  ADD COLUMN IF NOT EXISTS verified            boolean    NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS invited_at          timestamptz,
  ADD COLUMN IF NOT EXISTS commission_rate     numeric,
  ADD COLUMN IF NOT EXISTS agent_code          text,
  ADD COLUMN IF NOT EXISTS languages           text,
  ADD COLUMN IF NOT EXISTS speciality          text,
  ADD COLUMN IF NOT EXISTS off_day             text,
  ADD COLUMN IF NOT EXISTS notes               text,
  ADD COLUMN IF NOT EXISTS rejection_reason    text,
  ADD COLUMN IF NOT EXISTS senior              boolean    NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS farmers_helped      integer    NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS visits              integer    NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating              numeric(2,1),
  ADD COLUMN IF NOT EXISTS nin                 text,
  ADD COLUMN IF NOT EXISTS photo_url           text,
  ADD COLUMN IF NOT EXISTS bank_name           text,
  ADD COLUMN IF NOT EXISTS bank_account        text,
  ADD COLUMN IF NOT EXISTS commission_payout_phone text,
  ADD COLUMN IF NOT EXISTS lat                 numeric,
  ADD COLUMN IF NOT EXISTS lng                 numeric;

-- ─── 3) orders.agent_id — referrer link for leaderboard (B9) ────────
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS agent_id uuid REFERENCES app_users(id);

CREATE INDEX IF NOT EXISTS idx_orders_agent_id ON orders(agent_id);

-- ─── 4) traceability_batches.archived (B11) ─────────────────────────
ALTER TABLE traceability_batches
  ADD COLUMN IF NOT EXISTS archived boolean NOT NULL DEFAULT false;

-- ─── 5) chatbot_conversations — UI display columns (M5) ─────────────
ALTER TABLE chatbot_conversations
  ADD COLUMN IF NOT EXISTS farmer_name text,
  ADD COLUMN IF NOT EXISTS channel     text;

-- ─── 6) farm_visits — dashboard donut columns (B8) ──────────────────
-- The dashboard expects visit_type, rating, farmer_id. The existing
-- migration only created fo_id + ask_rating + urgency. Add what's
-- needed; keep old columns intact for backward compatibility.
ALTER TABLE farm_visits
  ADD COLUMN IF NOT EXISTS visit_type text   DEFAULT 'visit',
  ADD COLUMN IF NOT EXISTS rating     numeric(2,1),
  ADD COLUMN IF NOT EXISTS farmer_id  uuid REFERENCES app_users(id);

-- ─── 7) staff_profiles.email — UI needs email visible in user list ──
-- auth.users.email isn't readable from the client; mirror it onto
-- staff_profiles via the auto-create trigger so the table can show it.
ALTER TABLE staff_profiles
  ADD COLUMN IF NOT EXISTS email text;

-- Update the trigger to also copy email
CREATE OR REPLACE FUNCTION handle_new_staff_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO staff_profiles (id, full_name, role, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    COALESCE((NEW.raw_user_meta_data->>'role')::staff_role, 'outlet_clerk'),
    NEW.email
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    role      = EXCLUDED.role,
    email     = EXCLUDED.email;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$;

-- Backfill email for existing staff (the MD created via setup.html)
UPDATE staff_profiles s
SET email = u.email
FROM auth.users u
WHERE s.id = u.id AND (s.email IS NULL OR s.email = '');

-- ─── 8) app_sessions table — DAU tracking (B6) ──────────────────────
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

-- Mobile clients write their own session; admin staff can read all
DROP POLICY IF EXISTS "app_sessions_insert_any" ON app_sessions;
CREATE POLICY "app_sessions_insert_any" ON app_sessions
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "staff_read_all" ON app_sessions;
CREATE POLICY "staff_read_all" ON app_sessions
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- ─── 9) hire_bookings table — For Hire bookings tab (B7) ────────────
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

-- Sequence for booking numbers (HB-YYYY-NNNNN)
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

-- ─── 10) Verify ──────────────────────────────────────────────────────
SELECT 'staff_role values'   AS what, string_agg(enumlabel,', ') AS v FROM pg_enum WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname='staff_role')
UNION ALL SELECT 'user_status values', string_agg(enumlabel,', ') FROM pg_enum WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname='user_status')
UNION ALL SELECT 'app_users.verified exists', (SELECT count(*)::text FROM information_schema.columns WHERE table_name='app_users' AND column_name='verified')
UNION ALL SELECT 'orders.agent_id exists',    (SELECT count(*)::text FROM information_schema.columns WHERE table_name='orders'    AND column_name='agent_id')
UNION ALL SELECT 'staff_profiles.email exists', (SELECT count(*)::text FROM information_schema.columns WHERE table_name='staff_profiles' AND column_name='email')
UNION ALL SELECT 'app_sessions exists',       (SELECT count(*)::text FROM information_schema.tables WHERE table_name='app_sessions')
UNION ALL SELECT 'hire_bookings exists',      (SELECT count(*)::text FROM information_schema.tables WHERE table_name='hire_bookings');

SET row_security = on;
