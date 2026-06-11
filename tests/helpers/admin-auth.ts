/**
 * Admin auth helpers for the platform tests.
 *
 * The admin platform uses email + password (not OTP) and optionally a
 * TOTP factor. For deterministic test runs we:
 *   1. Use a dedicated qa-admin test account
 *   2. Skip MFA on this account (MFA flow has its own focused spec)
 *
 * The first call to ensureAdminAccount() will create the account if it
 * doesn't exist yet, using the service role key. Idempotent — re-runs
 * are no-ops.
 */
import { Page, expect } from '@playwright/test';
import { adminClient } from './supabase';

export const ADMIN_TEST_EMAIL    = 'qa-admin@example.com';
export const ADMIN_TEST_PASSWORD = process.env.ADMIN_TEST_PASSWORD || 'QaAdmin!Long_Pwd_2026';
export const ADMIN_TEST_NAME     = 'QA Admin';

/**
 * Idempotently create (or update) the test admin user. Returns the user id.
 * Adds a staff_profiles row with role='it_admin' so app_users staff-only
 * RLS allows the tests to manipulate other users.
 */
export async function ensureAdminAccount(): Promise<string> {
  const admin = adminClient();
  const SUPA_URL = process.env.SUPABASE_URL!;
  const SVC      = process.env.SUPABASE_SERVICE_KEY!;

  // 1. Does an auth user already exist?
  const listRes = await fetch(`${SUPA_URL}/auth/v1/admin/users?per_page=200`, {
    headers: { apikey: SVC, Authorization: `Bearer ${SVC}` },
  }).then(r => r.json());
  const existing = (listRes.users || []).find(
    (u: any) => (u.email || '').toLowerCase() === ADMIN_TEST_EMAIL.toLowerCase()
  );

  let userId: string;
  if (existing) {
    userId = existing.id;
    // Reset password just in case it drifted
    await fetch(`${SUPA_URL}/auth/v1/admin/users/${userId}`, {
      method: 'PUT',
      headers: {
        apikey: SVC,
        Authorization: `Bearer ${SVC}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        password: ADMIN_TEST_PASSWORD,
        email_confirm: true,
        user_metadata: { full_name: ADMIN_TEST_NAME, role: 'md' },
      }),
    });
  } else {
    const create = await fetch(`${SUPA_URL}/auth/v1/admin/users`, {
      method: 'POST',
      headers: {
        apikey: SVC,
        Authorization: `Bearer ${SVC}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: ADMIN_TEST_EMAIL,
        password: ADMIN_TEST_PASSWORD,
        email_confirm: true,
        user_metadata: { full_name: ADMIN_TEST_NAME, role: 'md' },
      }),
    }).then(r => r.json());
    userId = create.id;
  }

  // 2. Ensure staff_profiles row exists with `md` role so test runs aren't
  // blocked by role-based page restrictions (`it_admin` cannot reach Products,
  // Orders, etc., which most specs need).
  await admin.from('staff_profiles').upsert(
    {
      id:                 userId,
      full_name:          ADMIN_TEST_NAME,
      role:               'md',
      two_factor_enabled: false,
      active:             true,
    },
    { onConflict: 'id' }
  );

  // 3. Wipe any stale MFA factors left by a prior MFA-spec run. Multiple
  // accumulated factors can cause the enrollment UI to behave differently
  // (e.g. "Already enrolled" branch instead of fresh setup).
  try {
    const factorsRes = await fetch(`${SUPA_URL}/auth/v1/admin/users/${userId}/factors`, {
      headers: { apikey: SVC, Authorization: `Bearer ${SVC}` },
    });
    const factorsData: any = await factorsRes.json().catch(() => ({}));
    const factors = factorsData.factors || factorsData || [];
    for (const f of Array.isArray(factors) ? factors : []) {
      await fetch(`${SUPA_URL}/auth/v1/admin/users/${userId}/factors/${f.id}`, {
        method: 'DELETE',
        headers: { apikey: SVC, Authorization: `Bearer ${SVC}` },
      });
    }
  } catch (_) { /* best-effort cleanup */ }

  return userId;
}

/**
 * Sign in to the admin platform via the email/password form.
 * Assumes no MFA on the test account.
 *
 * Crucially, waits for `APP.profile` to be populated AFTER admin.html lands —
 * the platform fetches `staff_profiles` asynchronously, and if a test clicks a
 * sidebar item before that fetch resolves, `navigate()` reads `profile?.role`
 * as undefined and falls back to `outlet_clerk` (dashboard + orders only).
 */
export async function adminSignIn(page: Page) {
  await ensureAdminAccount();
  await page.goto('/index.html');
  await page.locator('input[type="email"], #emailInput').first().fill(ADMIN_TEST_EMAIL);
  await page.locator('input[type="password"], #passwordInput').first().fill(ADMIN_TEST_PASSWORD);
  await page.locator('#loginBtn, button[type="submit"], button:has-text("Sign in"), button:has-text("Continue")').first().click();
  await page.waitForURL(/admin\.html/, { timeout: 15_000 });
  // Wait for the role to be loaded onto the global APP object. Until this
  // resolves, every adminNav() call is silently blocked by the role check.
  await page.waitForFunction(
    () => (window as any).APP?.profile?.role,
    null,
    { timeout: 15_000 }
  );
}

/**
 * Click a sidebar nav item by data-page attribute. More reliable than
 * `text=/foo/i` which can match page-title H2s or other text nodes.
 *
 * Verifies the target `#page-<dataPage>` becomes `.active` (and therefore
 * visible) — if it doesn't within 8s, throws a clear error rather than letting
 * later locators time out with "element is not visible".
 */
export async function adminNav(page: Page, dataPage: string) {
  await page
    .locator(`aside button.sb-item[data-page="${dataPage}"], button.sb-item[data-page="${dataPage}"]`)
    .first()
    .click();
  // Wait for the page wrapper to actually go .active (display:block). If it
  // doesn't, the user's role likely doesn't grant access to this page — the
  // toast "Not available for your role" would have fired.
  await page.waitForSelector(`#page-${dataPage}.active`, { timeout: 8_000 });
  // Give content (KPIs, lists, table rows) a moment to fetch + render.
  await page.waitForTimeout(800);
}

/**
 * Sign out via the profile menu — used in test teardown to ensure
 * each spec starts from a clean state.
 */
export async function adminSignOut(page: Page) {
  await page.evaluate(() => {
    try {
      // @ts-ignore - sb is global on the admin page
      window.sb?.auth?.signOut?.();
    } catch (_) {}
    try { localStorage.clear(); sessionStorage.clear(); } catch (_) {}
  });
}
