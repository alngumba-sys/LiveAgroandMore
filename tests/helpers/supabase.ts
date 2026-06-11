/**
 * Supabase admin helpers — used by tests for OTP bypass, user creation,
 * and cleanup. All operations here use the SERVICE ROLE key, which
 * bypasses RLS. Do NOT export this client to test code that simulates a
 * normal user — those tests should use the anon key.
 */
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';

dotenv.config();

const SUPABASE_URL = process.env.SUPABASE_URL!;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY!;
const ANON_KEY = process.env.SUPABASE_ANON_KEY!;

if (!SUPABASE_URL || !SERVICE_KEY || !ANON_KEY) {
  throw new Error(
    'Missing env vars. Copy tests/.env.example to tests/.env and fill in SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_ANON_KEY.'
  );
}

let _admin: SupabaseClient | null = null;
let _anon: SupabaseClient | null = null;

export function adminClient(): SupabaseClient {
  if (!_admin) {
    _admin = createClient(SUPABASE_URL, SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
  }
  return _admin;
}

export function anonClient(): SupabaseClient {
  if (!_anon) {
    _anon = createClient(SUPABASE_URL, ANON_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
  }
  return _anon;
}

/**
 * Generate a 6-digit OTP for a given email without sending any real email.
 * Returns the OTP code as a string. If the user doesn't exist yet, Supabase
 * creates it as part of generate_link.
 */
export async function generateOtp(email: string): Promise<string> {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/admin/generate_link`, {
    method: 'POST',
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      type: 'magiclink',
      email,
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`generate_link failed (${res.status}): ${text}`);
  }
  const data = await res.json();
  if (!data.email_otp) throw new Error('No email_otp in response: ' + JSON.stringify(data));
  return data.email_otp as string;
}

/**
 * Delete an auth user by email. Idempotent — silently succeeds if no user.
 */
export async function deleteAuthUser(email: string): Promise<void> {
  const admin = adminClient();
  const list = await fetch(
    `${SUPABASE_URL}/auth/v1/admin/users?per_page=200`,
    {
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`,
      },
    }
  ).then(r => r.json());
  const users = (list.users || []).filter(
    (u: any) => (u.email || '').toLowerCase() === email.toLowerCase()
  );
  for (const u of users) {
    await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${u.id}`, {
      method: 'DELETE',
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`,
      },
    });
  }
}

/**
 * Delete all app_users rows matching an email pattern (used by cleanup).
 */
export async function deleteAppUserByEmail(email: string): Promise<void> {
  const admin = adminClient();
  await admin.from('app_users').delete().eq('email', email.toLowerCase());
}

/**
 * Delete a product by name (for cleanup after admin add-product tests).
 */
export async function deleteProductByName(name: string): Promise<void> {
  const admin = adminClient();
  await admin.from('products').delete().eq('name', name);
}

/**
 * Generate a unique QA email so test runs don't collide.
 *   qa-test-1715900000-7263@example.com
 */
export function qaEmail(prefix = 'qa-test'): string {
  const ts = Date.now();
  const r = Math.floor(Math.random() * 10000);
  return `${prefix}-${ts}-${r}@example.com`;
}

/**
 * Generate a unique QA product name.
 */
export function qaProductName(prefix = 'QA Test Product'): string {
  return `${prefix} ${Date.now()}`;
}
