-- ============================================================
-- Fix: any signed-in STAFF member can change CMS / advisory images.
--
-- Symptom: an admin could edit a Seasonal Tip's text (advisory_content)
-- but the image upload failed silently. Cause: the cms-images storage
-- write policies only allowed staff_profiles roles 'md' / 'it_admin',
-- while text edits are allowed for the broader staff set. So a non-md
-- staffer is blocked at upload time.
--
-- This broadens the cms-images bucket write/update/delete policies to
-- ANY user present in staff_profiles (still staff-only, never public).
-- Run once in the Supabase SQL editor (project: agroandmorehub.com).
-- Safe to re-run.
-- ============================================================

-- Make sure the bucket exists (idempotent).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cms-images','cms-images', true, 2*1024*1024,
        array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Replace the role-restricted write policies with staff-membership ones.
drop policy if exists cms_images_staff_write  on storage.objects;
drop policy if exists cms_images_staff_update on storage.objects;
drop policy if exists cms_images_staff_delete on storage.objects;

create policy cms_images_staff_write
  on storage.objects for insert
  with check (
    bucket_id = 'cms-images'
    and exists (select 1 from public.staff_profiles where id = auth.uid())
  );

create policy cms_images_staff_update
  on storage.objects for update
  using (
    bucket_id = 'cms-images'
    and exists (select 1 from public.staff_profiles where id = auth.uid())
  );

create policy cms_images_staff_delete
  on storage.objects for delete
  using (
    bucket_id = 'cms-images'
    and exists (select 1 from public.staff_profiles where id = auth.uid())
  );

-- Public read is unchanged (cms_images_public_read) so the farmer app can
-- still fetch the images without authentication.
