-- ═══════════════════════════════════════════════════════════════════
-- AGRO AND MORE — FULL DEMO-DATA WIPE  (FINAL, 2026-05-25)
-- Keeps ONLY:  md@agroandmore.co.ug  (same password — auth row untouched)
--              + outlets, fx_rates, settings, cms_images (config)
-- Wipes:       all app_users, products, orders, prices, content,
--              chatbot, traceability, hire providers, farm visits,
--              weather alerts, audit log, push notifications, OTPs,
--              and every other auth.users row.
--
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to run more than once.
-- ═══════════════════════════════════════════════════════════════════

SET row_security = off;

DO $wipe_all$
DECLARE
  md_auth_id uuid;
BEGIN
  -- Resolve MD's auth ID
  SELECT id INTO md_auth_id
  FROM auth.users
  WHERE email = 'md@agroandmore.co.ug'
  LIMIT 1;

  -- Break self-FK on app_users so DELETE works
  UPDATE app_users SET referral_agent_id = NULL
  WHERE referral_agent_id IS NOT NULL;

  -- Null out staff FKs on config tables we KEEP (avoid cascade blocks)
  UPDATE fx_rates SET updated_by = NULL WHERE updated_by IS NOT NULL;
  UPDATE settings SET updated_by = NULL WHERE updated_by IS NOT NULL;

  -- ── Delete in FK-safe order ──────────────────────────────────────
  DELETE FROM diaspora_order_items;
  DELETE FROM diaspora_orders;
  DELETE FROM order_items;
  DELETE FROM orders;
  ALTER SEQUENCE IF EXISTS order_number_seq RESTART WITH 1;

  DELETE FROM chatbot_messages;
  DELETE FROM chatbot_conversations;

  DELETE FROM traceability_stages;
  DELETE FROM traceability_batches;

  DELETE FROM hire_providers;

  DELETE FROM product_outlet_stock;
  DELETE FROM product_bulk_prices;
  DELETE FROM product_images;
  DELETE FROM products;

  DELETE FROM produce_prices;
  DELETE FROM advisory_content;
  DELETE FROM knowledge_base;
  DELETE FROM push_notifications;
  DELETE FROM audit_log;

  -- Tables added in later migrations — skip silently if absent
  BEGIN DELETE FROM farm_visits;     EXCEPTION WHEN undefined_table THEN NULL; END;
  BEGIN DELETE FROM weather_alerts;  EXCEPTION WHEN undefined_table THEN NULL; END;
  BEGIN DELETE FROM sms_otp_codes;   EXCEPTION WHEN undefined_table THEN NULL; END;

  -- App users last (farmers, agents, FOs, diaspora)
  DELETE FROM app_users;

  -- ── Auth users: keep ONLY the MD ────────────────────────────────
  -- Deleting from auth.users cascades to staff_profiles (ON DELETE CASCADE)
  IF md_auth_id IS NOT NULL THEN
    DELETE FROM auth.users WHERE id <> md_auth_id;
    RAISE NOTICE '✓ Wipe complete. MD preserved: %', md_auth_id;
  ELSE
    RAISE WARNING '⚠ md@agroandmore.co.ug NOT found in auth.users — nothing deleted from auth. Create the MD first via setup.html.';
  END IF;

  RAISE NOTICE '✓ Preserved: outlets, fx_rates, settings, cms_images, MD account.';
END $wipe_all$;

SET row_security = on;

-- ── Verification (read-only) ────────────────────────────────────────
SELECT 'auth.users remaining'  AS what, count(*)::text AS n FROM auth.users
UNION ALL SELECT 'staff_profiles', count(*)::text FROM staff_profiles
UNION ALL SELECT 'app_users',      count(*)::text FROM app_users
UNION ALL SELECT 'products',       count(*)::text FROM products
UNION ALL SELECT 'orders',         count(*)::text FROM orders
UNION ALL SELECT 'diaspora_orders',count(*)::text FROM diaspora_orders
UNION ALL SELECT 'produce_prices', count(*)::text FROM produce_prices
UNION ALL SELECT 'outlets (KEPT)', count(*)::text FROM outlets
UNION ALL SELECT 'settings (KEPT)',count(*)::text FROM settings;
