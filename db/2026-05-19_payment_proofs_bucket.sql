-- ─────────────────────────────────────────────────────────────────────
-- Migration: payment-proofs storage bucket + RLS
--
-- Fixes the checkout error:
--   "Upload failed: new row violates row-level security policy"
--
-- Cause: the `payment-proofs` storage bucket either didn't exist or had
-- no INSERT policy permitting authenticated end-users (customers) to
-- upload their own MoMo/Airtel screenshots.
--
-- Run in Supabase SQL editor:
--   https://app.supabase.com/project/nqyutflqzjjueemirgzr/sql
-- ─────────────────────────────────────────────────────────────────────

-- ─── 1) Create / update the bucket ───────────────────────────────────
-- Public read so the admin order-detail page can display the screenshot
-- without juggling signed URLs. 5 MB cap matches the client-side limit.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'payment-proofs',
  'payment-proofs',
  true,
  5 * 1024 * 1024,
  array['image/jpeg','image/png','image/webp','application/pdf']
)
on conflict (id) do update
  set public            = excluded.public,
      file_size_limit   = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ─── 2) Storage RLS policies ─────────────────────────────────────────
-- Path convention (from app.html handleProofPick):
--    {customerId}/{timestamp}-{random}.{ext}
-- where `{customerId}` is the auth.uid() of the signed-in shopper, or
-- the literal string 'guest' for the rare unauth checkout path.
--
-- Policies:
--   - Public read (so MD/IT admin can preview proofs in the order page)
--   - Authenticated INSERT for own folder (customerId == auth.uid())
--     plus a permissive fallback for the 'guest/' prefix so checkout
--     still works if a session blip drops the auth.
--   - Staff (md / it_admin / ops) can update + delete any object.
do $$
begin
  -- Drop any prior versions to avoid silent conflicts when re-running.
  if exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='payment_proofs_public_read')   then drop policy payment_proofs_public_read   on storage.objects; end if;
  if exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='payment_proofs_user_insert')   then drop policy payment_proofs_user_insert   on storage.objects; end if;
  if exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='payment_proofs_guest_insert')  then drop policy payment_proofs_guest_insert  on storage.objects; end if;
  if exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='payment_proofs_staff_update')  then drop policy payment_proofs_staff_update  on storage.objects; end if;
  if exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='payment_proofs_staff_delete')  then drop policy payment_proofs_staff_delete  on storage.objects; end if;
  if exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='payment_proofs_user_delete_own') then drop policy payment_proofs_user_delete_own on storage.objects; end if;
end$$;

-- 2a) Public read — keeps the admin proof preview simple.
create policy payment_proofs_public_read
  on storage.objects for select
  using (bucket_id = 'payment-proofs');

-- 2b) Authenticated user can upload into their own folder.
--     split_part(name, '/', 1) is the {customerId} prefix.
create policy payment_proofs_user_insert
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'payment-proofs'
    and split_part(name, '/', 1) = auth.uid()::text
  );

-- 2c) Anon fallback for the rare unauthenticated "guest" checkout path
--     (handleProofPick uses 'guest' when window.__amProfile is missing).
create policy payment_proofs_guest_insert
  on storage.objects for insert
  to anon, authenticated
  with check (
    bucket_id = 'payment-proofs'
    and split_part(name, '/', 1) = 'guest'
  );

-- 2d) Staff (MD / IT admin) can update any proof object — e.g.
--     replacing a corrupted screenshot during reconciliation.
create policy payment_proofs_staff_update
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'payment-proofs'
    and exists (
      select 1 from public.staff_profiles
      where id = auth.uid() and role in ('md','it_admin')
    )
  );

-- 2e) Staff (MD / IT admin) can delete any proof object.
create policy payment_proofs_staff_delete
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'payment-proofs'
    and exists (
      select 1 from public.staff_profiles
      where id = auth.uid() and role in ('md','it_admin')
    )
  );

-- 2f) A customer can also delete their own unverified proof (matches the
--     "remove" button in the checkout proof card).
create policy payment_proofs_user_delete_own
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'payment-proofs'
    and split_part(name, '/', 1) = auth.uid()::text
  );

-- ─── 3) Sanity check ─────────────────────────────────────────────────
-- select policyname, cmd from pg_policies
--  where schemaname='storage' and tablename='objects'
--    and policyname like 'payment_proofs_%'
--  order by policyname;
