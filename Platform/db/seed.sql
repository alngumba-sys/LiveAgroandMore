-- ============================================================
-- AGRO AND MORE — Seed Data (Demo / Testing)
-- Run AFTER schema.sql in the Supabase SQL Editor
-- ============================================================

-- ─── SAMPLE PRODUCTS ────────────────────────────────────────
INSERT INTO products (name, category, brand, price_ugx, total_stock, status, show_on_shop, description_en) VALUES
  ('Longe 5 OPV Maize Seed 5kg',       'Seeds',          'NARO',        28000,  412, 'active', true, 'High-yielding open-pollinated maize variety suited to central and eastern Uganda. Matures in 90-100 days.'),
  ('NABE 15 Bean Seed 2kg',             'Seeds',          'NARO',        16500,  220, 'active', true, 'Climbing bean variety with good resistance to Bean Common Mosaic Virus. Popular in highland areas.'),
  ('Hass Avocado Seedling (Grafted)',   'Seeds',          'AgroNursery', 8500,   340, 'active', true, 'Grafted Hass avocado seedling, ready for transplanting. Produces within 2-3 years.'),
  ('DAP Fertilizer 50kg',               'Fertilizers',    'Yara',        220000,  84, 'active', true, 'Di-Ammonium Phosphate fertilizer for planting. Ideal for maize, beans, and vegetables.'),
  ('Urea 50kg',                         'Fertilizers',    'Yara',        195000,  12, 'active', true, 'Nitrogen fertilizer for top-dressing. Apply 4-6 weeks after planting.'),
  ('CAN Fertilizer 50kg',               'Fertilizers',    'Balton',      185000, 200, 'active', true, 'Calcium Ammonium Nitrate — ideal for coffee and horticulture top-dressing.'),
  ('Mancozeb 80WP 1kg',                 'Crop Protection','BASF',         18000,   0, 'active', true, 'Broad-spectrum fungicide. Effective against late blight, early blight, and downy mildew.'),
  ('Round-up Herbicide 1L',             'Crop Protection','Bayer',        35000,  46, 'active', true, 'Systemic herbicide for pre-planting weed control. Do not apply to crops.'),
  ('Dimethoate 40EC 1L',                'Crop Protection','FMC',          22000,  78, 'active', true, 'Insecticide for aphids, mites, and coffee berry borer control.'),
  ('Agrolyser Knapsack Sprayer 16L',    'Tools',          'Agrolyser',   120000,   9, 'active', true, 'Durable 16-litre knapsack sprayer with adjustable nozzle. 2-year warranty.'),
  ('Watermaster Drip Kit (0.25 acre)',  'Irrigation',     'Netafim',     380000,  15, 'active', true, 'Complete drip irrigation kit for 0.25 acre. Includes pipes, emitters, and filters.'),
  ('Post-harvest Tarpaulin 10m x 10m', 'Post-harvest',   'Agritech UG', 95000,   32, 'active', true, 'Heavy-duty UV-resistant drying tarpaulin. Ideal for coffee and maize drying.');

-- ─── OUTLET STOCK ───────────────────────────────────────────
DO $$
DECLARE
  p_id uuid; o_id uuid;
BEGIN
  FOR p_id IN SELECT id FROM products LOOP
    FOR o_id IN SELECT id FROM outlets LOOP
      INSERT INTO product_outlet_stock (product_id, outlet_id, stock)
      VALUES (p_id, o_id, FLOOR(RANDOM() * 50)::integer)
      ON CONFLICT (product_id, outlet_id) DO NOTHING;
    END LOOP;
  END LOOP;
END $$;

-- ─── PRODUCE PRICES (current month) ─────────────────────────
INSERT INTO produce_prices (crop, unit, month, central_ugx, eastern_ugx, northern_ugx, western_ugx) VALUES
  ('Matooke',              'bunch', DATE_TRUNC('month', NOW()),  18000,  14500,  12000,  20000),
  ('Maize grain',          'kg',    DATE_TRUNC('month', NOW()),   1200,   1100,    950,   1250),
  ('Beans (NABE)',         'kg',    DATE_TRUNC('month', NOW()),   3400,   3200,   3100,   3600),
  ('Coffee (Robusta FAQ)', 'kg',    DATE_TRUNC('month', NOW()),   9800,   NULL,    NULL,  10200),
  ('Hass Avocado',         'kg',    DATE_TRUNC('month', NOW()),   2200,   1950,   1800,   2400),
  ('Cassava (fresh)',      'kg',    DATE_TRUNC('month', NOW()),    650,    600,    550,    700),
  ('Sweet potato',         'kg',    DATE_TRUNC('month', NOW()),    900,    850,    750,   1000),
  ('Groundnuts (shelled)', 'kg',    DATE_TRUNC('month', NOW()),   5200,   4800,   4500,   5500),
  ('Sorghum',              'kg',    DATE_TRUNC('month', NOW()),   1100,   1050,   1000,   1150),
  ('Sunflower seed',       'kg',    DATE_TRUNC('month', NOW()),   2300,   2100,   2000,   2400);

-- ─── SAMPLE APP USERS ────────────────────────────────────────
INSERT INTO app_users (full_name, phone, email, role, status, district, sub_county) VALUES
  ('Nakato Nabirye',   '+256772456123', 'nakato@example.ug',    'farmer',       'active',           'Mpigi',    'Nkozi'),
  ('Kato Ibrahim',     '+256772889004', 'kato.i@example.ug',   'agent',        'active',           'Kampala',  'Kawempe'),
  ('Okello James',     '+256700321777', 'j.okello@example.ug', 'field_officer','pending_approval',  'Butambala', NULL),
  ('Byaruhanga Moses', '+256782100200', 'moses.b@example.ug',  'agent',        'active',           'Mbarara',  'Kakoba'),
  ('Tumusiime David',  '+256772400100', 'david.t@example.ug',  'farmer',       'active',           'Gomba',    'Maddu'),
  ('Nankya Justine',   '+256701550300', 'justine.n@example.ug','agent',        'active',           'Masaka',   'Masaka City'),
  ('Achieng Grace',    '+256712900400', 'grace.a@example.ug',  'field_officer','active',           'Gulu',     'Gulu City'),
  ('Ssemakula Robert', '+447700900111', 'rob.s@example.com',   'diaspora',     'active',           NULL,       NULL);

UPDATE app_users SET country_of_residence = 'United Kingdom' WHERE full_name = 'Ssemakula Robert';

-- ─── FIX ORDER-NUMBER TRIGGER ────────────────────────────────
-- The original trigger used EXTRACT(EPOCH FROM NOW()) % 100000 which
-- produces the same value for all INSERTs within the same second.
-- Replace it with a sequence-backed version that is always unique.
CREATE SEQUENCE IF NOT EXISTS order_number_seq START 1;

CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.order_number := 'AM-' || TO_CHAR(NOW(), 'YYYY-MM') || '-'
    || LPAD(CAST(nextval('order_number_seq') AS text), 5, '0');
  RETURN NEW;
END;
$$;

-- ─── SAMPLE ORDERS ───────────────────────────────────────────
-- Clean up any orders from previous seed runs so this is safe to re-run.
DELETE FROM order_items
WHERE order_id IN (
  SELECT id FROM orders
  WHERE customer_name IN ('Nakato Nabirye', 'Tumusiime David')
    AND payment_method = 'mobile_money'
);
DELETE FROM orders
WHERE customer_name IN ('Nakato Nabirye', 'Tumusiime David')
  AND payment_method = 'mobile_money';

DO $$
DECLARE
  farmer_id  uuid; outlet_id uuid; product_id uuid; ord_id uuid;
BEGIN
  SELECT id INTO farmer_id FROM app_users WHERE full_name = 'Nakato Nabirye';
  SELECT id INTO outlet_id FROM outlets WHERE name = 'Mpigi Town';
  SELECT id INTO product_id FROM products WHERE name LIKE '%DAP%' LIMIT 1;

  -- order_number is generated by the trigger via order_number_seq (guaranteed unique)
  INSERT INTO orders (customer_id, customer_name, customer_phone, outlet_id, status, payment_method, total_ugx, subtotal_ugx)
  VALUES (farmer_id, 'Nakato Nabirye', '+256772456123', outlet_id, 'awaiting_payment', 'mobile_money', 440000, 440000)
  RETURNING id INTO ord_id;

  INSERT INTO order_items (order_id, product_id, product_name, quantity, unit_price_ugx, total_ugx)
  VALUES (ord_id, product_id, 'DAP Fertilizer 50kg', 2, 220000, 440000);

  SELECT id INTO outlet_id FROM outlets WHERE name = 'Kampala Nakawa';
  SELECT id INTO farmer_id FROM app_users WHERE full_name = 'Tumusiime David';

  INSERT INTO orders (customer_id, customer_name, customer_phone, outlet_id, status, payment_method, total_ugx, subtotal_ugx)
  VALUES (farmer_id, 'Tumusiime David', '+256772400100', outlet_id, 'confirmed', 'mobile_money', 57000, 57000)
  RETURNING id INTO ord_id;

  SELECT id INTO product_id FROM products WHERE name LIKE '%Mancozeb%' LIMIT 1;
  INSERT INTO order_items (order_id, product_id, product_name, quantity, unit_price_ugx, total_ugx)
  VALUES (ord_id, product_id, 'Mancozeb 80WP 1kg', 2, 18000, 36000);

  SELECT id INTO product_id FROM products WHERE name LIKE '%Round-up%' LIMIT 1;
  INSERT INTO order_items (order_id, product_id, product_name, quantity, unit_price_ugx, total_ugx)
  VALUES (ord_id, product_id, 'Round-up Herbicide 1L', 1, 35000, 35000);
END $$;

-- ─── SAMPLE TRACEABILITY BATCH ───────────────────────────────
DELETE FROM traceability_stages WHERE batch_id IN (
  SELECT id FROM traceability_batches WHERE batch_number = 'AM-COF-2026-04-00218'
);
DELETE FROM traceability_batches WHERE batch_number = 'AM-COF-2026-04-00218';

DO $$
DECLARE farmer_id uuid;
BEGIN
  SELECT id INTO farmer_id FROM app_users WHERE full_name = 'Nakato Nabirye';
  INSERT INTO traceability_batches (batch_number, crop, farmer_id, farmer_name, district, harvest_date, current_stage, destination, weight_kg)
  VALUES ('AM-COF-2026-04-00218', 'coffee_robusta', farmer_id, 'Nakato Nabirye', 'Mpigi', '2026-04-02', 'warehoused', 'Hamburg, Germany', 2400);
END $$;

-- ─── SAMPLE FOR-HIRE PROVIDER ────────────────────────────────
DELETE FROM hire_providers
WHERE phone IN ('+256772400100', '+256782100200', '+256700321777');

INSERT INTO hire_providers (name, phone, whatsapp, category, equipment_make, equipment_model, equipment_capacity, districts_covered, day_rate_ugx, rating, verified, active)
VALUES
  ('Tumusiime David',  '+256772400100', '+256772400100', 'tractor',    'Massey Ferguson', '375',   '75HP',     ARRAY['Gomba','Butambala','Mpigi'], 180000, 4.6, true,  true),
  ('Byaruhanga Moses', '+256782100200', '+256782100200', 'water_pump', 'Grundfos',        'CM3',   '3000L/hr', ARRAY['Mbarara','Isingiro'],        85000,  4.2, true,  true),
  ('Okello James',     '+256700321777', '+256700321777', 'thresher',   'VOTEX',           'BM300', '500kg/hr', ARRAY['Gulu','Amuru'],              120000, 4.0, false, true);

-- ─── SAMPLE ADVISORY CONTENT ────────────────────────────────
INSERT INTO advisory_content (type, title, description, language, source_url, duration_seconds, published_at, visibility)
VALUES
  ('video',  'Pruning your Hass avocado before the rains',  'Step-by-step guide on pruning Hass avocado trees for better yields.', 'luganda', 'https://youtu.be/example1', 272, NOW() - INTERVAL '13 days', 'public'),
  ('video',  'Fall Armyworm control in maize',              'Identification and management of Fall Armyworm in maize fields.',     'english', 'https://drive.google.com/example2', 370, NOW() - INTERVAL '20 days', 'public'),
  ('radio',  'CBS Radio: Coffee prices this month',         'Monthly price roundup and market outlook with Byaruhanga Moses.',    'luganda', 'https://soundcloud.com/example3',  2280, NOW() - INTERVAL '17 days', 'public'),
  ('seasonal_tip', 'Prepare your seedbeds before the long rains begin', 'Early preparation increases germination rates by up to 40%.', 'english', NULL, NULL, NOW() - INTERVAL '5 days', 'public');

-- ─── KNOWLEDGE BASE ENTRIES ──────────────────────────────────
INSERT INTO knowledge_base (title, description, file_type) VALUES
  ('Product Catalogue 2026',           'Full product list with prices and agronomic details.', 'pdf'),
  ('Advisory Video Transcripts',       'Text transcripts of all advisory videos for AI indexing.', 'docx'),
  ('Weather & Planting Calendar',      'Regional weather patterns and recommended planting windows.', 'pdf'),
  ('Frequently Asked Questions',       'Common farmer questions and expert answers.', 'pdf'),
  ('Current Produce Price Sheet',      'Monthly price guide exported from the system.', 'csv');

-- ─── SAMPLE PUSH NOTIFICATIONS ──────────────────────────────
INSERT INTO push_notifications (title, body, target_audience, target_districts, status, scheduled_at) VALUES
  ('New fertilizer price drop!', 'DAP 50kg now UGX 210,000. Order now from your nearest outlet.', 'farmers', ARRAY['Mpigi','Butambala','Gomba'], 'scheduled', NOW() + INTERVAL '1 day'),
  ('Rains forecast: prepare your seedbeds', 'Met forecast shows rains arriving in 2 weeks across Central Region.', 'farmers', ARRAY['Kampala','Wakiso','Mpigi'], 'sent', NOW() - INTERVAL '3 days');
