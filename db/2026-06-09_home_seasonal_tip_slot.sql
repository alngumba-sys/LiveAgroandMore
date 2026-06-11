-- ============================================================
-- Add a managed image slot for the farmer Home "Seasonal Tip" card.
--   Appears automatically under admin Settings → Images (the admin
--   auto-discovers cms_images rows). Setting this slot's image is the
--   one obvious place to change the Home seasonal-tip picture; if it's
--   left empty the card falls back to the latest Advisory seasonal tip's
--   thumbnail.
-- The farmer app patches <img data-cms-slot="home-seasonal-tip"> on boot.
-- Run once in the Supabase SQL editor (project: agroandmorehub.com).
-- Safe to re-run.
-- ============================================================
insert into public.cms_images (slot, label, description, category, recommended, sort_order)
values (
  'home-seasonal-tip',
  'Home seasonal tip image',
  'Photo on the Seasonal Tip card on the farmer Home screen. Leave empty to use the latest Advisory seasonal tip image.',
  'home',
  '800×450 landscape, < 150 KB',
  21
)
on conflict (slot) do nothing;
