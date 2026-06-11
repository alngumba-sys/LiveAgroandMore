-- ─────────────────────────────────────────────────────────────────────
-- Migration: SMS OTP via Africa's Talking, alongside the existing
-- email OTP. Users will receive the same login code on BOTH email
-- and SMS — they can enter whichever arrives first.
--
-- Run in Supabase SQL editor:
--   https://app.supabase.com/project/nqyutflqzjjueemirgzr/sql
-- ─────────────────────────────────────────────────────────────────────

-- ─── 1) sms_otp_codes table ──────────────────────────────────────────
-- One row per (email, code) attempt. Code is stored as a SHA-256 hash;
-- we never store plaintext. 5-minute TTL, 5-attempt cap.
create table if not exists public.sms_otp_codes (
  id              uuid primary key default gen_random_uuid(),
  email           text not null,
  phone           text not null,
  code_hash       text not null,
  expires_at      timestamptz not null,
  attempts        int  not null default 0,
  consumed_at     timestamptz,
  created_at      timestamptz not null default now(),
  ip_hash         text                                -- best-effort, for abuse tracking
);

comment on table public.sms_otp_codes
  is 'SHA-256-hashed SMS OTPs sent via Africa''s Talking. Service-role only.';

create index if not exists sms_otp_codes_email_idx       on public.sms_otp_codes(email, created_at desc);
create index if not exists sms_otp_codes_expires_idx     on public.sms_otp_codes(expires_at)
  where consumed_at is null;

-- RLS — locked down to service role only. Edge functions use the
-- service key so they can insert / update / select freely; clients
-- never touch this table directly.
alter table public.sms_otp_codes enable row level security;

drop policy if exists sms_otp_codes_no_anon_read on public.sms_otp_codes;
create policy sms_otp_codes_no_anon_read on public.sms_otp_codes
  for select using (false);            -- nobody but service role

drop policy if exists sms_otp_codes_no_anon_write on public.sms_otp_codes;
create policy sms_otp_codes_no_anon_write on public.sms_otp_codes
  for all using (false) with check (false);

-- ─── 2) Africa's Talking credentials in `settings` ───────────────────
-- These rows are read by the Edge Function via service key.
insert into public.settings (key, value) values
  ('at_username',   'sandbox'),
  ('at_api_key',    ''),
  ('at_sender_id',  '')
on conflict (key) do nothing;

-- ─── 3) Tighten RLS on settings rows holding the AT secrets ──────────
-- The existing `settings` table is admin-readable by default. We don't
-- want non-MD staff (or worse, anon clients) reading the AT API key.
-- Convention used elsewhere in this DB: prefix sensitive keys with
-- `at_` and gate via RLS.
--
-- If the existing settings RLS already allows broad read, you may need
-- to tighten it. Verify with:
--   select * from pg_policies where tablename='settings';
--
-- For now, an Edge Function with service key bypasses RLS so SMS still
-- works even if a future policy tightens this further.

-- ─── 4) Convenience: housekeeping function ───────────────────────────
-- Delete consumed or expired OTP codes older than 1 day, so the table
-- stays small. Run via Supabase pg_cron, or manually as needed.
create or replace function public.sms_otp_cleanup()
returns void language plpgsql security definer as $$
begin
  delete from sms_otp_codes
   where consumed_at is not null and consumed_at < now() - interval '1 day';
  delete from sms_otp_codes
   where expires_at < now() - interval '1 day';
end $$;

comment on function public.sms_otp_cleanup
  is 'Deletes consumed / expired SMS-OTP rows older than 24h. Run hourly via pg_cron.';

-- ─── 5) Sanity check ─────────────────────────────────────────────────
-- After running this, set the live AT credentials in the admin UI:
--   Settings → SMS provider → enter username + API key + sender ID → Save.
-- The Edge Functions will pick them up automatically on next call.
