-- ─────────────────────────────────────────────────────────────────────
-- Migration: admin-controlled image slots ("CMS Images")
--
-- Goal: let MD / IT admin swap key images in the mobile app without a
-- deploy. Add as many slots as you need — the admin Settings → Images
-- tab auto-discovers them, and the app patches any <img>/element with
-- data-cms-slot="<slot>" on boot.
--
-- Run in Supabase SQL editor:
--   https://app.supabase.com/project/nqyutflqzjjueemirgzr/sql
-- ─────────────────────────────────────────────────────────────────────

-- ─── 1) Storage bucket ───────────────────────────────────────────────
-- Public bucket so the mobile app can fetch images without signed URLs.
-- File size limit 2 MB (admins also resize client-side, so this is a
-- safety net not the primary limit).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'cms-images',
  'cms-images',
  true,
  2 * 1024 * 1024,
  array['image/jpeg','image/png','image/webp','image/gif']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Storage RLS: anyone can read; only md / it_admin staff can write.
do $$
begin
  -- Read policy: public access
  if not exists (
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects' and policyname='cms_images_public_read'
  ) then
    create policy cms_images_public_read
      on storage.objects for select
      using (bucket_id = 'cms-images');
  end if;

  -- Write policy: must be authenticated AND in staff_profiles as md/it_admin
  if not exists (
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects' and policyname='cms_images_staff_write'
  ) then
    create policy cms_images_staff_write
      on storage.objects for insert
      with check (
        bucket_id = 'cms-images'
        and exists (
          select 1 from public.staff_profiles
          where id = auth.uid() and role in ('md','it_admin')
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects' and policyname='cms_images_staff_update'
  ) then
    create policy cms_images_staff_update
      on storage.objects for update
      using (
        bucket_id = 'cms-images'
        and exists (
          select 1 from public.staff_profiles
          where id = auth.uid() and role in ('md','it_admin')
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects' and policyname='cms_images_staff_delete'
  ) then
    create policy cms_images_staff_delete
      on storage.objects for delete
      using (
        bucket_id = 'cms-images'
        and exists (
          select 1 from public.staff_profiles
          where id = auth.uid() and role in ('md','it_admin')
        )
      );
  end if;
end$$;

-- ─── 2) cms_images table ─────────────────────────────────────────────
-- One row per "slot" — a named placeholder the app reads on boot.
create table if not exists public.cms_images (
  slot            text primary key,
  label           text not null,
  description     text,
  category        text not null default 'general',  -- group in admin UI
  url             text,                              -- public Storage URL (or external)
  alt_text        text,
  recommended     text,                              -- e.g. "1200×800 landscape, < 200 KB"
  sort_order      int  not null default 100,
  updated_at      timestamptz not null default now(),
  updated_by      uuid references auth.users(id)
);

comment on table public.cms_images
  is 'Admin-controlled image slots used by the mobile app — boot reads all rows and patches anything with data-cms-slot=<slot>.';

create index if not exists cms_images_category_idx on public.cms_images(category, sort_order);

-- Auto-update updated_at on UPDATE
create or replace function public.cms_images_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end $$;

drop trigger if exists cms_images_set_updated_at on public.cms_images;
create trigger cms_images_set_updated_at
  before update on public.cms_images
  for each row execute function public.cms_images_set_updated_at();

-- ─── 3) Table RLS ────────────────────────────────────────────────────
alter table public.cms_images enable row level security;

drop policy if exists cms_images_public_read   on public.cms_images;
drop policy if exists cms_images_staff_insert  on public.cms_images;
drop policy if exists cms_images_staff_update  on public.cms_images;
drop policy if exists cms_images_staff_delete  on public.cms_images;

create policy cms_images_public_read
  on public.cms_images for select
  using (true);  -- mobile app reads anonymously

create policy cms_images_staff_insert
  on public.cms_images for insert
  with check (
    exists (select 1 from staff_profiles where id = auth.uid() and role in ('md','it_admin'))
  );

create policy cms_images_staff_update
  on public.cms_images for update
  using (
    exists (select 1 from staff_profiles where id = auth.uid() and role in ('md','it_admin'))
  );

create policy cms_images_staff_delete
  on public.cms_images for delete
  using (
    exists (select 1 from staff_profiles where id = auth.uid() and role in ('md','it_admin'))
  );

-- ─── 4) Seed the initial slots ───────────────────────────────────────
-- Adding a new slot later is just another insert here + a data-cms-slot
-- attribute on the matching element in app.html. No code change needed
-- in admin or in the app's boot function.
insert into public.cms_images (slot, label, description, category, recommended, sort_order)
values
  ('onboarding-hero',     'Onboarding hero photo',  'The photo on the welcome screen (before "Get Started").', 'onboarding', '1000×667 landscape, < 200 KB',  10),
  ('home-promo-banner',   'Home promo banner',      'Optional banner shown above categories on home — leave empty to hide.', 'home',     '750×280 landscape, < 150 KB', 20),
  ('cat-seeds',           'Category: Seeds',        'Tile background on the shop home.',                          'categories', '600×400 square-ish, < 80 KB', 30),
  ('cat-fertilizers',     'Category: Fertilizers',  'Tile background on the shop home.',                          'categories', '600×400 square-ish, < 80 KB', 31),
  ('cat-crop-protection', 'Category: Crop Protection','Tile background on the shop home.',                        'categories', '600×400 square-ish, < 80 KB', 32),
  ('cat-tools',           'Category: Tools',        'Tile background on the shop home.',                          'categories', '600×400 square-ish, < 80 KB', 33),
  ('cat-irrigation',      'Category: Irrigation',   'Tile background on the shop home.',                          'categories', '600×400 square-ish, < 80 KB', 34),
  ('cat-livestock',       'Category: Livestock',    'Tile background on the shop home.',                          'categories', '600×400 square-ish, < 80 KB', 35),
  ('cat-post-harvest',    'Category: Post-harvest', 'Tile background on the shop home.',                          'categories', '600×400 square-ish, < 80 KB', 36),
  ('advisory-bot-hero',   'AgroBot hero',           'Header image on the Ask AgroBot screen.',                    'advisory',   '750×280 landscape, < 100 KB', 40),
  ('diaspora-hero',       'Diaspora landing hero',  'Top of the Diaspora home screen.',                           'diaspora',   '750×280 landscape, < 150 KB', 50)
on conflict (slot) do nothing;

-- ─── 5) Sanity check: list slots ─────────────────────────────────────
-- select slot, label, category, url is not null as has_image, updated_at
--   from public.cms_images order by category, sort_order;
