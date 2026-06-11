-- ═══════════════════════════════════════════════════════════════════
-- AGRO AND MORE — Full demo-data wipe  (v2 — corrected FK order)
-- Keeps ONLY the MD account (md@agroandmore.co.ug).
-- Everything else — all app users, products, orders, prices, content —
-- is deleted so the MD can start fresh and create real company accounts.
--
-- Run in Supabase SQL Editor (Dashboard → SQL Editor → New query)
-- Safe to run more than once.
-- ═══════════════════════════════════════════════════════════════════

-- Bypass RLS for this session (SQL Editor runs as postgres superuser,
-- but being explicit prevents any policy from quietly blocking deletes)
SET row_security = off;

DO $wipe_all$
DECLARE
  md_auth_id uuid;
BEGIN

  -- ── Resolve the MD's auth ID ──────────────────────────────────────
  SELECT id INTO md_auth_id
  FROM auth.users
  WHERE email = 'md@agroandmore.co.ug'
  LIMIT 1;

  -- ── PRE-STEP A: break the self-referencing FK on app_users ────────
  -- app_users.referral_agent_id → app_users(id)  (no CASCADE)
  -- Must be NULL-ed before we can DELETE any app_users row.
  UPDATE app_users SET referral_agent_id = NULL
  WHERE referral_agent_id IS NOT NULL;

  -- ── PRE-STEP B: clear staff FK on kept config tables ─────────────
  -- fx_rates and settings are NOT deleted, but their updated_by column
  -- points at staff_profiles rows that will cascade-delete when we
  -- remove their auth.users entries.  NULL them first.
  UPDATE fx_rates SET updated_by = NULL WHERE updated_by IS NOT NULL;
  UPDATE settings SET updated_by = NULL WHERE updated_by IS NOT NULL;


  -- ══ DATA TABLES — deleted in FK-safe order ══════════════════════

  -- ── 1. Diaspora order items (child of diaspora_orders) ────────────
  DELETE FROM diaspora_order_items;

  -- ── 2. Diaspora orders ───────────────────────────────────────────
  DELETE FROM diaspora_orders;

  -- ── 3. Regular order items (child of orders) ─────────────────────
  DELETE FROM order_items;

  -- ── 4. Regular orders ────────────────────────────────────────────
  DELETE FROM orders;

  -- ── 5. Reset the order-number sequence so next order = AM-YYYY-MM-00001
  ALTER SEQUENCE IF EXISTS order_number_seq RESTART WITH 1;

  -- ── 6. Chatbot messages (child of chatbot_conversations) ──────────
  DELETE FROM chatbot_messages;

  -- ── 7. Chatbot conversations (references app_users — clear first) ─
  DELETE FROM chatbot_conversations;

  -- ── 8. Traceability stages (child of traceability_batches) ────────
  DELETE FROM traceability_stages;

  -- ── 9. Traceability batches (references app_users + staff_profiles)
  DELETE FROM traceability_batches;

  -- ── 10. Hire providers ───────────────────────────────────────────
  DELETE FROM hire_providers;

  -- ── 11. Product outlet stock ──────────────────────────────────────
  DELETE FROM product_outlet_stock;

  -- ── 12. Product bulk prices ───────────────────────────────────────
  DELETE FROM product_bulk_prices;

  -- ── 13. Product images ───────────────────────────────────────────
  DELETE FROM product_images;

  -- ── 14. Products ─────────────────────────────────────────────────
  DELETE FROM products;

  -- ── 15. Produce prices ───────────────────────────────────────────
  DELETE FROM produce_prices;

  -- ── 16. Advisory content ─────────────────────────────────────────
  DELETE FROM advisory_content;

  -- ── 17. Knowledge base ───────────────────────────────────────────
  DELETE FROM knowledge_base;

  -- ── 18. Push notifications ───────────────────────────────────────
  DELETE FROM push_notifications;

  -- ── 19. Audit log ────────────────────────────────────────────────
  DELETE FROM audit_log;

  -- ── 20. App users (farmers, agents, field officers, diaspora) ─────
  -- The MD is a staff_profiles user, not an app_user, so we delete ALL.
  DELETE FROM app_users;


  -- ══ AUTH USERS — remove everyone except the MD ══════════════════
  -- Deleting from auth.users cascades to staff_profiles (ON DELETE CASCADE).
  -- fx_rates.updated_by and settings.updated_by were already NULL-ed above
  -- so the cascade won't hit a blocking FK.

  IF md_auth_id IS NOT NULL THEN
    DELETE FROM auth.users WHERE id <> md_auth_id;
    RAISE NOTICE '✓ Auth users wiped — MD preserved: %', md_auth_id;
  ELSE
    RAISE WARNING '⚠ MD account (md@agroandmore.co.ug) not found in auth.users — wiping ALL auth users. Re-run setup.html after this.';
    DELETE FROM auth.users;
  END IF;

  RAISE NOTICE '✓ Full demo-data wipe complete.';
  RAISE NOTICE '  Products, orders, users, prices, content — all cleared.';
  RAISE NOTICE '  Outlets, settings, fx_rates preserved.';

END $wipe_all$;

-- Restore default RLS behaviour for this session
SET row_security = on;
