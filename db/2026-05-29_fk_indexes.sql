-- ════════════════════════════════════════════════════════════════
-- Migration: 2026-05-29_fk_indexes.sql
-- Add missing indexes on foreign-key columns (audit finding)
-- ════════════════════════════════════════════════════════════════

-- staff_profiles
CREATE INDEX IF NOT EXISTS idx_staff_profiles_outlet_id         ON staff_profiles(outlet_id);

-- app_users
CREATE INDEX IF NOT EXISTS idx_app_users_referral_agent          ON app_users(referral_agent_id);

-- products
CREATE INDEX IF NOT EXISTS idx_products_created_by               ON products(created_by);

-- product_images
CREATE INDEX IF NOT EXISTS idx_product_images_product_id         ON product_images(product_id);

-- product_bulk_prices
CREATE INDEX IF NOT EXISTS idx_product_bulk_prices_product_id    ON product_bulk_prices(product_id);

-- product_outlet_stock
CREATE INDEX IF NOT EXISTS idx_product_outlet_stock_product_id   ON product_outlet_stock(product_id);
CREATE INDEX IF NOT EXISTS idx_product_outlet_stock_outlet_id    ON product_outlet_stock(outlet_id);

-- produce_prices
CREATE INDEX IF NOT EXISTS idx_produce_prices_updated_by         ON produce_prices(updated_by);

-- orders
CREATE INDEX IF NOT EXISTS idx_orders_customer_id                ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_outlet_id                  ON orders(outlet_id);

-- order_items
CREATE INDEX IF NOT EXISTS idx_order_items_order_id              ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id            ON order_items(product_id);

-- diaspora_orders
CREATE INDEX IF NOT EXISTS idx_diaspora_orders_outlet_id         ON diaspora_orders(outlet_id);

-- diaspora_order_items
CREATE INDEX IF NOT EXISTS idx_diaspora_order_items_order_id     ON diaspora_order_items(diaspora_order_id);
CREATE INDEX IF NOT EXISTS idx_diaspora_order_items_product_id   ON diaspora_order_items(product_id);

-- traceability_batches
CREATE INDEX IF NOT EXISTS idx_trace_batches_farmer_id           ON traceability_batches(farmer_id);
CREATE INDEX IF NOT EXISTS idx_trace_batches_created_by          ON traceability_batches(created_by);

-- traceability_stages
CREATE INDEX IF NOT EXISTS idx_trace_stages_batch_id             ON traceability_stages(batch_id);

-- advisory_content
CREATE INDEX IF NOT EXISTS idx_advisory_created_by               ON advisory_content(created_by);

-- chatbot_conversations
CREATE INDEX IF NOT EXISTS idx_chat_conversations_farmer_id      ON chatbot_conversations(farmer_id);
CREATE INDEX IF NOT EXISTS idx_chat_conversations_escalated_to   ON chatbot_conversations(escalated_to);

-- chatbot_messages  ← highest impact: every conversation load JOINs here
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_id     ON chatbot_messages(conversation_id);

-- knowledge_base
CREATE INDEX IF NOT EXISTS idx_knowledge_base_created_by         ON knowledge_base(created_by);

-- push_notifications
CREATE INDEX IF NOT EXISTS idx_push_notifs_created_by            ON push_notifications(created_by);

-- fx_rates
CREATE INDEX IF NOT EXISTS idx_fx_rates_updated_by               ON fx_rates(updated_by);

-- audit_log
CREATE INDEX IF NOT EXISTS idx_audit_log_staff_id                ON audit_log(staff_id);

-- settings
CREATE INDEX IF NOT EXISTS idx_settings_updated_by               ON settings(updated_by);

-- hire_bookings: farmer_id was missed in original PART4 migration
CREATE INDEX IF NOT EXISTS idx_hire_bookings_farmer_id           ON hire_bookings(farmer_id);
