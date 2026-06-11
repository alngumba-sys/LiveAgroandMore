-- ═══════════════════════════════════════════════════════════════════
-- PART 2 of 4 — Column additions on existing tables
-- Run after PART 1 succeeds.
-- ═══════════════════════════════════════════════════════════════════

SET row_security = off;

-- app_users — missing columns referenced by the admin SPA
ALTER TABLE app_users
  ADD COLUMN IF NOT EXISTS verified                boolean      NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS invited_at              timestamptz,
  ADD COLUMN IF NOT EXISTS commission_rate         numeric,
  ADD COLUMN IF NOT EXISTS agent_code              text,
  ADD COLUMN IF NOT EXISTS languages               text,
  ADD COLUMN IF NOT EXISTS speciality              text,
  ADD COLUMN IF NOT EXISTS off_day                 text,
  ADD COLUMN IF NOT EXISTS notes                   text,
  ADD COLUMN IF NOT EXISTS rejection_reason        text,
  ADD COLUMN IF NOT EXISTS senior                  boolean      NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS farmers_helped          integer      NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS visits                  integer      NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating                  numeric(2,1),
  ADD COLUMN IF NOT EXISTS nin                     text,
  ADD COLUMN IF NOT EXISTS photo_url               text,
  ADD COLUMN IF NOT EXISTS bank_name               text,
  ADD COLUMN IF NOT EXISTS bank_account            text,
  ADD COLUMN IF NOT EXISTS commission_payout_phone text,
  ADD COLUMN IF NOT EXISTS lat                     numeric,
  ADD COLUMN IF NOT EXISTS lng                     numeric;

-- orders — agent referral link for leaderboard
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS agent_id uuid REFERENCES app_users(id);
CREATE INDEX IF NOT EXISTS idx_orders_agent_id ON orders(agent_id);

-- traceability_batches.archived
ALTER TABLE traceability_batches
  ADD COLUMN IF NOT EXISTS archived boolean NOT NULL DEFAULT false;

-- chatbot_conversations — UI display columns
ALTER TABLE chatbot_conversations
  ADD COLUMN IF NOT EXISTS farmer_name text,
  ADD COLUMN IF NOT EXISTS channel     text;

-- farm_visits — dashboard donut columns
ALTER TABLE farm_visits
  ADD COLUMN IF NOT EXISTS visit_type text DEFAULT 'visit',
  ADD COLUMN IF NOT EXISTS rating     numeric(2,1),
  ADD COLUMN IF NOT EXISTS farmer_id  uuid REFERENCES app_users(id);

-- staff_profiles.email + backfill
ALTER TABLE staff_profiles
  ADD COLUMN IF NOT EXISTS email text;

UPDATE staff_profiles s
SET email = u.email
FROM auth.users u
WHERE s.id = u.id AND (s.email IS NULL OR s.email = '');

SET row_security = on;

-- Verify
SELECT 'app_users.verified',         (SELECT count(*) FROM information_schema.columns WHERE table_name='app_users' AND column_name='verified')
UNION ALL SELECT 'orders.agent_id',          (SELECT count(*) FROM information_schema.columns WHERE table_name='orders' AND column_name='agent_id')
UNION ALL SELECT 'staff_profiles.email',     (SELECT count(*) FROM information_schema.columns WHERE table_name='staff_profiles' AND column_name='email')
UNION ALL SELECT 'traceability_batches.archived', (SELECT count(*) FROM information_schema.columns WHERE table_name='traceability_batches' AND column_name='archived')
UNION ALL SELECT 'chatbot_conversations.farmer_name', (SELECT count(*) FROM information_schema.columns WHERE table_name='chatbot_conversations' AND column_name='farmer_name')
UNION ALL SELECT 'farm_visits.visit_type',   (SELECT count(*) FROM information_schema.columns WHERE table_name='farm_visits' AND column_name='visit_type');
