-- ============================================================
-- AGRO AND MORE — Full Database Schema
-- Project: nqyutflqzjjueemirgzr
-- Run this entire file in the Supabase SQL Editor
-- ============================================================

-- ─── EXTENSIONS ─────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- for fuzzy search

-- ─── ENUMS ──────────────────────────────────────────────────
CREATE TYPE staff_role         AS ENUM ('md','sales_manager','it_admin','agronomist','outlet_clerk');
CREATE TYPE app_user_role      AS ENUM ('farmer','agent','field_officer','diaspora');
CREATE TYPE user_status        AS ENUM ('pending_approval','active','blocked');
CREATE TYPE order_status       AS ENUM ('pending','awaiting_payment','confirmed','dispatched','delivered','completed','cancelled');
CREATE TYPE payment_method     AS ENUM ('mobile_money','cash','visa');
CREATE TYPE content_lang       AS ENUM ('english','luganda','runyankole','ateso','acholi');
CREATE TYPE content_type       AS ENUM ('video','radio','seasonal_tip');
CREATE TYPE hire_category      AS ENUM ('tractor','water_pump','thresher','transport');
CREATE TYPE trace_crop         AS ENUM ('coffee_robusta','coffee_arabica','hass_avocado');
CREATE TYPE batch_stage        AS ENUM ('harvested','warehoused','processing','in_transit','exported');
CREATE TYPE notif_status       AS ENUM ('draft','scheduled','sent');
CREATE TYPE notif_audience     AS ENUM ('all','farmers','agents','field_officers','diaspora');

-- ─── OUTLETS ────────────────────────────────────────────────
CREATE TABLE outlets (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  district    text NOT NULL,
  sub_county  text,
  address     text,
  phone       text,
  active      boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);

INSERT INTO outlets (name, district, sub_county) VALUES
  ('Mpigi Town',     'Mpigi',    'Mpigi Town Council'),
  ('Butambala',      'Butambala','Gombe'),
  ('Gomba',          'Gomba',    'Maddu'),
  ('Masaka Central', 'Masaka',   'Masaka City'),
  ('Kampala Nakawa', 'Kampala',  'Nakawa'),
  ('Mbale',          'Mbale',    'Mbale City'),
  ('Gulu',           'Gulu',     'Gulu City'),
  ('Jinja',          'Jinja',    'Jinja City');

-- ─── STAFF PROFILES ─────────────────────────────────────────
CREATE TABLE staff_profiles (
  id                   uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name            text NOT NULL,
  role                 staff_role NOT NULL DEFAULT 'outlet_clerk',
  phone                text,
  outlet_id            uuid REFERENCES outlets(id),
  avatar_url           text,
  two_factor_enabled   boolean NOT NULL DEFAULT false,
  active               boolean NOT NULL DEFAULT true,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_staff_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO staff_profiles (id, full_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    COALESCE((NEW.raw_user_meta_data->>'role')::staff_role, 'outlet_clerk')
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    role      = EXCLUDED.role;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW; -- Never block user creation if profile insert fails
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE handle_new_staff_user();

-- ─── APP USERS (farmers, agents, field officers, diaspora) ──
CREATE TABLE app_users (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name             text NOT NULL,
  phone                 text UNIQUE NOT NULL,
  email                 text UNIQUE,
  role                  app_user_role NOT NULL DEFAULT 'farmer',
  status                user_status NOT NULL DEFAULT 'pending_approval',
  district              text,
  sub_county            text,
  country_of_residence  text,
  national_id           text,
  profile_photo_url     text,
  referral_agent_id     uuid REFERENCES app_users(id),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  last_active_at        timestamptz
);

-- ─── PRODUCTS ───────────────────────────────────────────────
CREATE TABLE products (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name                  text NOT NULL,
  category              text NOT NULL,
  brand                 text,
  sku                   text UNIQUE,
  description_en        text,
  description_lg        text,
  price_ugx             numeric NOT NULL DEFAULT 0,
  agent_price_ugx       numeric,
  diaspora_price_usd    numeric,
  total_stock           integer NOT NULL DEFAULT 0,
  status                text NOT NULL DEFAULT 'draft',
  show_on_shop          boolean NOT NULL DEFAULT false,
  show_diaspora         boolean NOT NULL DEFAULT false,
  feature_home          boolean NOT NULL DEFAULT false,
  active_ingredient     text,
  maaif_reg_number      text,
  reentry_interval_hrs  integer,
  created_by            uuid REFERENCES staff_profiles(id),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE product_images (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  url         text NOT NULL,
  sort_order  integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE product_bulk_prices (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  min_qty     integer NOT NULL,
  price_ugx   numeric NOT NULL
);

CREATE TABLE product_outlet_stock (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  outlet_id   uuid NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  stock       integer NOT NULL DEFAULT 0,
  UNIQUE(product_id, outlet_id)
);

-- ─── PRODUCE PRICES ─────────────────────────────────────────
CREATE TABLE produce_prices (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  crop          text NOT NULL,
  unit          text NOT NULL,
  month         date NOT NULL,
  central_ugx   numeric,
  eastern_ugx   numeric,
  northern_ugx  numeric,
  western_ugx   numeric,
  updated_by    uuid REFERENCES staff_profiles(id),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- ─── ORDERS ─────────────────────────────────────────────────
CREATE TABLE orders (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number        text UNIQUE NOT NULL,
  customer_id         uuid REFERENCES app_users(id),
  customer_name       text NOT NULL,
  customer_phone      text NOT NULL,
  outlet_id           uuid REFERENCES outlets(id),
  status              order_status NOT NULL DEFAULT 'pending',
  payment_method      payment_method,
  payment_reference   text,
  payment_proof_url   text,
  subtotal_ugx        numeric NOT NULL DEFAULT 0,
  delivery_fee_ugx    numeric NOT NULL DEFAULT 0,
  total_ugx           numeric NOT NULL DEFAULT 0,
  notes               text,
  dispatched_at       timestamptz,
  delivered_at        timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE order_items (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id      uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id    uuid REFERENCES products(id),
  product_name  text NOT NULL,
  quantity      integer NOT NULL DEFAULT 1,
  unit_price_ugx numeric NOT NULL,
  total_ugx     numeric NOT NULL
);

-- Sequence for unique order numbers (survives retries, concurrent inserts, same-second bursts)
CREATE SEQUENCE IF NOT EXISTS order_number_seq START 1;

-- Auto-generate order number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.order_number := 'AM-' || TO_CHAR(NOW(), 'YYYY-MM') || '-' || LPAD(CAST(nextval('order_number_seq') AS text), 5, '0');
  RETURN NEW;
END;
$$;
CREATE TRIGGER set_order_number BEFORE INSERT ON orders FOR EACH ROW EXECUTE PROCEDURE generate_order_number();

-- ─── DIASPORA ORDERS ────────────────────────────────────────
CREATE TABLE diaspora_orders (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number              text UNIQUE NOT NULL,
  payer_name                text NOT NULL,
  payer_email               text,
  payer_country             text NOT NULL,
  recipient_name            text NOT NULL,
  recipient_phone           text NOT NULL,
  recipient_district        text NOT NULL,
  outlet_id                 uuid REFERENCES outlets(id),
  status                    order_status NOT NULL DEFAULT 'awaiting_payment',
  total_usd                 numeric NOT NULL DEFAULT 0,
  total_ugx                 numeric NOT NULL DEFAULT 0,
  pickup_code               text,
  collected                 boolean NOT NULL DEFAULT false,
  collected_at              timestamptz,
  stripe_payment_intent_id  text,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE diaspora_order_items (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  diaspora_order_id   uuid NOT NULL REFERENCES diaspora_orders(id) ON DELETE CASCADE,
  product_id          uuid REFERENCES products(id),
  product_name        text NOT NULL,
  quantity            integer NOT NULL DEFAULT 1,
  unit_price_usd      numeric NOT NULL,
  total_usd           numeric NOT NULL
);

-- ─── TRACEABILITY ───────────────────────────────────────────
CREATE TABLE traceability_batches (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_number    text UNIQUE NOT NULL,
  crop            trace_crop NOT NULL,
  farmer_id       uuid REFERENCES app_users(id),
  farmer_name     text NOT NULL,
  district        text NOT NULL,
  harvest_date    date NOT NULL,
  current_stage   batch_stage NOT NULL DEFAULT 'harvested',
  destination     text,
  weight_kg       numeric,
  created_by      uuid REFERENCES staff_profiles(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE traceability_stages (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id      uuid NOT NULL REFERENCES traceability_batches(id) ON DELETE CASCADE,
  stage         batch_stage NOT NULL,
  location      text,
  officer_name  text,
  photo_url     text,
  notes         text,
  completed_at  timestamptz NOT NULL DEFAULT now()
);

-- ─── FOR HIRE PROVIDERS ─────────────────────────────────────
CREATE TABLE hire_providers (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name                text NOT NULL,
  phone               text NOT NULL,
  whatsapp            text,
  category            hire_category NOT NULL,
  equipment_make      text,
  equipment_model     text,
  equipment_capacity  text,
  districts_covered   text[] NOT NULL DEFAULT '{}',
  day_rate_ugx        numeric NOT NULL,
  availability_notes  text,
  rating              numeric(2,1),
  verified            boolean NOT NULL DEFAULT false,
  active              boolean NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

-- ─── ADVISORY CONTENT ───────────────────────────────────────
CREATE TABLE advisory_content (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type                    content_type NOT NULL,
  title                   text NOT NULL,
  description             text,
  language                content_lang NOT NULL DEFAULT 'english',
  source_url              text,
  thumbnail_url           text,
  duration_seconds        integer,
  target_districts        text[] DEFAULT '{}',
  target_roles            text[] DEFAULT '{}',
  visibility              text NOT NULL DEFAULT 'public',
  published_at            timestamptz,
  send_push_notification  boolean NOT NULL DEFAULT false,
  created_by              uuid REFERENCES staff_profiles(id),
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

-- ─── CHATBOT ────────────────────────────────────────────────
CREATE TABLE chatbot_conversations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_phone    text NOT NULL,
  farmer_id       uuid REFERENCES app_users(id),
  district        text,
  status          text NOT NULL DEFAULT 'active',
  escalated_to    uuid REFERENCES app_users(id),
  message_count   integer NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_message_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE chatbot_messages (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id     uuid NOT NULL REFERENCES chatbot_conversations(id) ON DELETE CASCADE,
  role                text NOT NULL,
  content             text NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE knowledge_base (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title           text NOT NULL,
  description     text,
  file_url        text,
  file_type       text,
  last_indexed_at timestamptz,
  created_by      uuid REFERENCES staff_profiles(id),
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- ─── PUSH NOTIFICATIONS ─────────────────────────────────────
CREATE TABLE push_notifications (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title             text NOT NULL,
  body              text NOT NULL,
  target_audience   notif_audience NOT NULL DEFAULT 'all',
  target_districts  text[] DEFAULT '{}',
  deep_link_type    text,
  deep_link_value   text,
  status            notif_status NOT NULL DEFAULT 'draft',
  scheduled_at      timestamptz,
  sent_at           timestamptz,
  recipient_count   integer,
  created_by        uuid REFERENCES staff_profiles(id),
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- ─── FX RATES ───────────────────────────────────────────────
CREATE TABLE fx_rates (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usd_to_ugx  numeric NOT NULL DEFAULT 3800,
  updated_by  uuid REFERENCES staff_profiles(id),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
INSERT INTO fx_rates (usd_to_ugx) VALUES (3800);

-- ─── AUDIT LOG ──────────────────────────────────────────────
CREATE TABLE audit_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id    uuid REFERENCES staff_profiles(id),
  staff_name  text,
  role        staff_role,
  action      text NOT NULL,
  target_type text,
  target_id   text,
  ip_address  text,
  notes       text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ─── SETTINGS ───────────────────────────────────────────────
CREATE TABLE settings (
  key         text PRIMARY KEY,
  value       jsonb NOT NULL,
  updated_by  uuid REFERENCES staff_profiles(id),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
INSERT INTO settings (key, value) VALUES
  ('commission_rate',    '"5"'),
  ('mtn_merchant_code',  '"256770"'),
  ('airtel_pay_code',    '"885511"'),
  ('sms_provider',       '"africas_talking"'),
  ('whatsapp_number',    '"+256700000000"'),
  ('stripe_test_mode',   'true'),
  ('org_name',           '"Agro and More Agri-Business Developers Limited"'),
  ('org_reg_number',     '"80020000987452"');

-- ─── ROW LEVEL SECURITY ─────────────────────────────────────
ALTER TABLE staff_profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE products             ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_images       ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_bulk_prices  ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_outlet_stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE produce_prices       ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders               ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items          ENABLE ROW LEVEL SECURITY;
ALTER TABLE diaspora_orders      ENABLE ROW LEVEL SECURITY;
ALTER TABLE diaspora_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE traceability_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE traceability_stages  ENABLE ROW LEVEL SECURITY;
ALTER TABLE hire_providers       ENABLE ROW LEVEL SECURITY;
ALTER TABLE advisory_content     ENABLE ROW LEVEL SECURITY;
ALTER TABLE chatbot_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE chatbot_messages     ENABLE ROW LEVEL SECURITY;
ALTER TABLE knowledge_base       ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_notifications   ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log            ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings             ENABLE ROW LEVEL SECURITY;
ALTER TABLE outlets              ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_rates             ENABLE ROW LEVEL SECURITY;

-- Helper: get current staff role
CREATE OR REPLACE FUNCTION current_staff_role()
RETURNS staff_role LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM staff_profiles WHERE id = auth.uid();
$$;

-- Authenticated staff can read everything
CREATE POLICY "staff_read_all" ON staff_profiles      FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON app_users           FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON products            FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON product_images      FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON product_bulk_prices FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON product_outlet_stock FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON produce_prices      FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON orders              FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON order_items         FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON diaspora_orders     FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON diaspora_order_items FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON traceability_batches FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON traceability_stages  FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON hire_providers      FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON advisory_content    FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON chatbot_conversations FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON chatbot_messages    FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON knowledge_base      FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON push_notifications  FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON audit_log           FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON settings            FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON outlets             FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_read_all" ON fx_rates            FOR SELECT USING (auth.uid() IS NOT NULL);

-- Staff can write (service_role bypasses RLS for admin ops)
CREATE POLICY "staff_write" ON products            FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON product_images      FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON product_bulk_prices FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON product_outlet_stock FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON produce_prices      FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON orders              FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON order_items         FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON diaspora_orders     FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON app_users           FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON hire_providers      FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON advisory_content    FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON traceability_batches FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON traceability_stages  FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON push_notifications  FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON knowledge_base      FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON audit_log           FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON settings            FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON fx_rates            FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "staff_write" ON staff_profiles      FOR UPDATE USING (auth.uid() = id);

-- ─── INDEXES ────────────────────────────────────────────────
CREATE INDEX idx_products_category    ON products(category);
CREATE INDEX idx_products_status      ON products(status);
CREATE INDEX idx_orders_status        ON orders(status);
CREATE INDEX idx_orders_created       ON orders(created_at DESC);
CREATE INDEX idx_app_users_role       ON app_users(role);
CREATE INDEX idx_app_users_status     ON app_users(status);
CREATE INDEX idx_produce_prices_month ON produce_prices(month DESC);
CREATE INDEX idx_audit_log_created    ON audit_log(created_at DESC);
CREATE INDEX idx_advisory_type        ON advisory_content(type);
