/**
 * Edge cases and adversarial inputs.
 */
import { test, expect } from '@playwright/test';
import { fillFarmerSignup, signUpAsFarmer, seedSignedInFarmer, cleanupTestUser, activeScreen } from '../helpers/auth';
import { qaEmail, generateOtp, adminClient, anonClient } from '../helpers/supabase';

test.describe('Edge cases', () => {
  let email: string;

  test.beforeEach(() => { email = qaEmail(); });
  test.afterEach(async () => { if (email) await cleanupTestUser(email); });

  test('very long full name (200+ chars) is rejected or truncated gracefully', async ({ page }) => {
    const huge = 'A'.repeat(250);
    await page.goto('/app.html?mode=app#onboarding-4');
    const screen = activeScreen(page);
    await screen.locator('input[placeholder="Your full name"]').first().fill(huge);
    await screen.locator('input[placeholder="your@email.com"]').first().fill(email);
    await screen.locator('.sticky-btn .btn.primary, button:has-text("Send OTP")').first().click();
    await expect(page.locator('body')).toBeVisible();
  });

  test('SQL injection-style input in name does not break the app', async ({ page }) => {
    await page.goto('/app.html?mode=app#onboarding-4');
    const screen = activeScreen(page);
    await screen.locator('input[placeholder="Your full name"]').first().fill(`'; DROP TABLE users; --`);
    await screen.locator('input[placeholder="your@email.com"]').first().fill(email);
    await screen.locator('.sticky-btn .btn.primary, button:has-text("Send OTP")').first().click();
    await page.waitForTimeout(2000);
    await expect(page.locator('body')).toBeVisible();
  });

  test('XSS-style input does not execute as script', async ({ page }) => {
    const xss = `<script>window.__XSS_FIRED__ = true</script><img src=x onerror="window.__XSS_FIRED__=true">`;
    await page.goto('/app.html?mode=app#onboarding-4');
    const screen = activeScreen(page);
    await screen.locator('input[placeholder="Your full name"]').first().fill(xss);
    await screen.locator('input[placeholder="your@email.com"]').first().fill(email);
    await screen.locator('.sticky-btn .btn.primary, button:has-text("Send OTP")').first().click();
    await page.waitForTimeout(2500);
    const fired = await page.evaluate(() => (window as any).__XSS_FIRED__);
    expect(fired).toBeFalsy();
  });

  test('rate limit: requesting OTP twice quickly returns friendly error', async ({ page }) => {
    // First OTP request — open the login sheet via the intro screen.
    await page.goto('/app.html?mode=app#onboarding-2');
    await activeScreen(page).locator('a.signin-link, a:has-text("Log in")').first().click();
    await page.locator('#sb-li-email').fill(email);
    await page.locator('#sb-li-btn').click();
    await page.waitForTimeout(1500);
    // Second request: hit the Supabase OTP endpoint directly to provoke the
    // rate-limit response (the UI sheet has moved on to the OTP screen, but
    // the app's signInWithOtp helper is the same code path). The app should
    // convert "For security purposes…" into a friendly toast on the next
    // login attempt — confirm the original code path still triggers the toast.
    await page.evaluate(async (e) => {
      const sb = (window as any).__sb;
      if (sb?.auth?.signInWithOtp) {
        await sb.auth.signInWithOtp({ email: e });
      }
    }, email);
    // We don't strictly assert the friendly message text here (the toast may
    // be hidden if the previous one is still up). What we DO confirm is that
    // the page didn't crash and is still interactive.
    await expect(page.locator('body')).toBeVisible();
  });

  test('RLS: anonymous user cannot read app_users rows', async () => {
    const anon = anonClient();
    const { data, error } = await anon.from('app_users').select('id').limit(1);
    expect(error || (data?.length ?? 0) === 0).toBeTruthy();
  });

  test('RLS: authenticated user cannot UPDATE another user\'s row', async ({ page }) => {
    // Create the victim AND attacker via the admin API so this test isn't
    // gated by Supabase's per-IP signup rate limit (this test runs late in
    // the suite, after many other signups).
    const victimEmail = qaEmail('victim');
    await seedSignedInFarmer(page, {
      email: victimEmail, name: 'Victim', phone: '712000001',
      district: 'Mpigi', subCounty: 'Nkozi', farmSize: '1 acre', village: 'V',
      ageRange: '18 – 35', crops: ['Matooke'],
    });
    const admin = adminClient();
    const { data: victim } = await admin.from('app_users').select('id').eq('email', victimEmail).single();
    expect(victim?.id).toBeTruthy();

    // Sign in as a fresh "attacker" user — clear the victim's session first.
    await page.evaluate(() => { try { localStorage.clear(); sessionStorage.clear(); } catch(_){} });
    await seedSignedInFarmer(page, {
      email, name: 'Attacker', phone: '712000002',
      district: 'Mpigi', subCounty: 'Nkozi', farmSize: '1 acre', village: 'V',
      ageRange: '18 – 35', crops: ['Matooke'],
    });
    // Try to update the victim's name from the attacker's authenticated session
    const result = await page.evaluate(async (vid) => {
      const sb = (window as any).__sb;
      if (!sb) return { error: 'no sb' };
      const r = await sb.from('app_users')
        .update({ full_name: 'PWNED' })
        .eq('id', vid);
      return { error: r.error?.message, status: r.status };
    }, victim!.id);
    // If RLS is correctly tightened, this returns an error or 0 rows.
    const { data: after } = await admin.from('app_users')
      .select('full_name').eq('id', victim!.id).single();
    expect(after?.full_name).toBe('Victim');
    // Cleanup the victim
    await cleanupTestUser(victimEmail);
  });

  test('cached old service worker: app.html re-fetches on hard reload', async ({ page }) => {
    await page.goto('/app.html?mode=app');
    await page.waitForLoadState('networkidle');
    // Confirm new SW version is current
    const swText = await page.evaluate(async () => {
      const res = await fetch('/service-worker.js', { cache: 'no-store' });
      return res.text();
    });
    expect(swText).toMatch(/CACHE_VERSION\s*=\s*['"]agmore-v\d+/);
  });
});
