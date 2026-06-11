-- ═══════════════════════════════════════════════════════════════════
-- AGRO AND MORE — Wipe all demo / seed data
-- Run once in the Supabase SQL Editor (Dashboard → SQL Editor → New query)
--
-- What this removes:
--   • 12 sample products + all their outlet-stock rows
--   • 10 produce-price rows (all seeded months)
--   • 8 sample app_users (identified by @example.ug / @example.com emails)
--   • All orders + order_items placed by those users
--   • 1 traceability batch + its stages
--   • 3 hire-provider rows seeded from those users
--   • 4 advisory-content rows
--   • 5 knowledge-base entries
--   • 2 push-notification rows
--
-- What this does NOT touch:
--   • Any real users, orders, or products you have added since go-live
--   • Schema, enums, triggers, buckets, or RLS policies
--   • Settings / config rows
--
-- Safe to run more than once (all deletes are WHERE-scoped).
-- ═══════════════════════════════════════════════════════════════════


-- ── 1. Seed user IDs (used throughout to scope deletes safely) ──────
-- We identify seed users by their @example.ug / @example.com emails.
-- If you have given any of these people real accounts, remove their
-- email from this list before running.

DO $wipe$
DECLARE
  seed_user_ids uuid[];
  seed_product_ids uuid[];
  seed_batch_ids uuid[];
BEGIN

  -- ── Collect seed user IDs ─────────────────────────────────────────
  SELECT ARRAY_AGG(id) INTO seed_user_ids
  FROM app_users
  WHERE email IN (
    'nakato@example.ug',
    'kato.i@example.ug',
    'j.okello@example.ug',
    'moses.b@example.ug',
    'david.t@example.ug',
    'justine.n@example.ug',
    'grace.a@example.ug',
    'rob.s@example.com'
  );

  -- ── Collect seed product IDs ──────────────────────────────────────
  SELECT ARRAY_AGG(id) INTO seed_product_ids
  FROM products
  WHERE name IN (
    'Longe 5 OPV Maize Seed 5kg',
    'NABE 15 Bean Seed 2kg',
    'Hass Avocado Seedling (Grafted)',
    'DAP Fertilizer 50kg',
    'Urea 50kg',
    'CAN Fertilizer 50kg',
    'Mancozeb 80WP 1kg',
    'Round-up Herbicide 1L',
    'Dimethoate 40EC 1L',
    'Agrolyser Knapsack Sprayer 16L',
    'Watermaster Drip Kit (0.25 acre)',
    'Post-harvest Tarpaulin 10m x 10m'
  );

  -- ── Collect seed traceability batch IDs ──────────────────────────
  SELECT ARRAY_AGG(id) INTO seed_batch_ids
  FROM traceability_batches
  WHERE batch_number = 'AM-COF-2026-04-00218';


  -- ── 2. Order items placed by seed users ──────────────────────────
  IF seed_user_ids IS NOT NULL THEN
    DELETE FROM order_items
    WHERE order_id IN (
      SELECT id FROM orders
      WHERE customer_id = ANY(seed_user_ids)
    );

    -- ── 3. Orders placed by seed users ───────────────────────────
    DELETE FROM orders
    WHERE customer_id = ANY(seed_user_ids);
  END IF;


  -- ── 4. Traceability stages + batches ─────────────────────────────
  IF seed_batch_ids IS NOT NULL THEN
    DELETE FROM traceability_stages
    WHERE batch_id = ANY(seed_batch_ids);

    DELETE FROM traceability_batches
    WHERE id = ANY(seed_batch_ids);
  END IF;


  -- ── 5. Hire-provider rows seeded from seed users ─────────────────
  IF seed_user_ids IS NOT NULL THEN
    DELETE FROM hire_providers
    WHERE phone IN (
      SELECT phone FROM app_users WHERE id = ANY(seed_user_ids)
    );
  END IF;


  -- ── 6. Any remaining order_items referencing seed products ────────
  -- Catches items on orders NOT placed by seed users (e.g. admin test
  -- orders, or orders whose customer_id didn't match the list above).
  IF seed_product_ids IS NOT NULL THEN
    DELETE FROM order_items
    WHERE product_id = ANY(seed_product_ids);
  END IF;


  -- ── 7. Product outlet-stock rows ────────────────────────────────
  IF seed_product_ids IS NOT NULL THEN
    DELETE FROM product_outlet_stock
    WHERE product_id = ANY(seed_product_ids);
  END IF;


  -- ── 8. Products ─────────────────────────────────────────────────
  IF seed_product_ids IS NOT NULL THEN
    DELETE FROM products
    WHERE id = ANY(seed_product_ids);
  END IF;


  -- ── 9. Seed app_users ────────────────────────────────────────────
  IF seed_user_ids IS NOT NULL THEN
    DELETE FROM app_users
    WHERE id = ANY(seed_user_ids);
  END IF;


  -- ── 10. Produce prices (all seeded rows) ─────────────────────────
  DELETE FROM produce_prices
  WHERE crop IN (
    'Matooke', 'Maize grain', 'Beans (NABE)', 'Coffee (Robusta FAQ)',
    'Hass Avocado', 'Cassava (fresh)', 'Sweet potato',
    'Groundnuts (shelled)', 'Sorghum', 'Sunflower seed'
  );


  -- ── 11. Advisory content (seeded rows only) ──────────────────────
  DELETE FROM advisory_content
  WHERE source_url IN (
    'https://youtu.be/example1',
    'https://drive.google.com/example2',
    'https://soundcloud.com/example3'
  )
  OR (source_url IS NULL AND title = 'Prepare your seedbeds before the long rains begin');


  -- ── 12. Knowledge-base seed entries ──────────────────────────────
  DELETE FROM knowledge_base
  WHERE title IN (
    'Product Catalogue 2026',
    'Advisory Video Transcripts',
    'Weather & Planting Calendar',
    'Frequently Asked Questions',
    'Current Produce Price Sheet'
  );


  -- ── 13. Push-notification seed rows ──────────────────────────────
  DELETE FROM push_notifications
  WHERE title IN (
    'New fertilizer price drop!',
    'Rains forecast: prepare your seedbeds'
  );


  RAISE NOTICE '✓ Demo data wipe complete.';
  RAISE NOTICE '  Users removed:        %', COALESCE(array_length(seed_user_ids, 1), 0);
  RAISE NOTICE '  Products removed:     %', COALESCE(array_length(seed_product_ids, 1), 0);
  RAISE NOTICE '  Batches removed:      %', COALESCE(array_length(seed_batch_ids, 1), 0);

END $wipe$;


-- ═══════════════════════════════════════════════════════════════════
-- OPTIONAL: Also wipe the Supabase Auth users for the seed accounts.
-- Uncomment the block below ONLY if you want to remove them from
-- auth.users as well (prevents login with those email addresses).
-- ---------------------------------------------------------------
-- DO $auth_wipe$
-- DECLARE r RECORD;
-- BEGIN
--   FOR r IN
--     SELECT au.id
--     FROM auth.users au
--     JOIN public.app_users pu ON pu.id = au.id
--     WHERE au.email IN (
--       'nakato@example.ug','kato.i@example.ug','j.okello@example.ug',
--       'moses.b@example.ug','david.t@example.ug','justine.n@example.ug',
--       'grace.a@example.ug','rob.s@example.com'
--     )
--   LOOP
--     DELETE FROM auth.users WHERE id = r.id;
--   END LOOP;
--   RAISE NOTICE '✓ Seed auth users removed.';
-- END $auth_wipe$;
-- ═══════════════════════════════════════════════════════════════════
