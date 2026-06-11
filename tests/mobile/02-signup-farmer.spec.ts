/**
 * Farmer signup — full happy-path + edge cases.
 * Uses OTP bypass (admin API) so no real emails sent.
 */
import { test, expect } from '@playwright/test';
import { signUpAsFarmer, fillFarmerSignup, cleanupTestUser, typeOtpAndVerify, activeScreen } from '../helpers/auth';
import { generateOtp, qaEmail, adminClient } from '../helpers/supabase';

test.describe('Farmer signup', () => {
  let testEmail: string;

  test.beforeEach(() => {
    testEmail = qaEmail();
  });

  test.afterEach(async () => {
    if (testEmail) await cleanupTestUser(testEmail);
  });

  test('happy path: new farmer signs up, OTP verified, lands on home', async ({ page }) => {
    await signUpAsFarmer(page, {
      email: testEmail,
      name: 'Andrew QA',
      phone: '712345678',
      district: 'Mpigi',
      subCounty: 'Nkozi',
      farmSize: '1 acre',
      village: 'Kayabwe',
      ageRange: '36 – 60',
      crops: ['Matooke', 'Coffee'],
    });
    // Greeting should include the first name (scope to the active home screen)
    await expect(activeScreen(page).locator('.greet .name').first()).toContainText('Andrew');
  });

  test('blocks send when name is empty', async ({ page }) => {
    await page.goto('/app.html?mode=app#onboarding-4');
    const screen = activeScreen(page);
    await screen.locator('input[placeholder="your@email.com"]').first().fill(testEmail);
    await screen.locator('.sticky-btn .btn.primary, button:has-text("Send OTP")').first().click();
    await expect(page.locator('#sb-toast')).toContainText(/full name/i);
  });

  test('blocks send when email is missing @', async ({ page }) => {
    await page.goto('/app.html?mode=app#onboarding-4');
    const screen = activeScreen(page);
    await screen.locator('input[placeholder="Your full name"]').first().fill('Test');
    await screen.locator('input[placeholder="your@email.com"]').first().fill('not-an-email');
    await screen.locator('.sticky-btn .btn.primary, button:has-text("Send OTP")').first().click();
    await expect(page.locator('#sb-toast')).toContainText(/valid email/i);
  });

  test('blocks send when agreement checkbox is unticked', async ({ page }) => {
    await page.goto('/app.html?mode=app#onboarding-4');
    const screen = activeScreen(page);
    // Fill EVERY required field so phone/district/etc don't trigger first —
    // the agreement check is the last validation.
    await screen.locator('input[placeholder="Your full name"]').first().fill('Test User');
    await screen.locator('input[placeholder="772 XXX XXX"]').first().fill('712345678');
    await screen.locator('input[placeholder="your@email.com"]').first().fill(testEmail);
    await screen.locator('select').nth(0).selectOption({ label: 'Mpigi' }).catch(() => {});
    await screen.locator('select').nth(1).selectOption({ label: 'Nkozi' }).catch(() => {});
    await screen.locator('.pill', { hasText: '18 – 35' }).first().click().catch(() => {});
    await screen.locator('.pill', { hasText: 'Matooke' }).first().click().catch(() => {});
    await screen.locator('select').nth(2).selectOption({ label: '1 acre' }).catch(() => {});
    await screen.locator('input[placeholder="e.g. Kayabwe"]').first().fill('Kayabwe');
    // Untick the agreement (it starts checked after wireSignup runs).
    await screen.locator('.checkbox').first().click();
    await screen.locator('.sticky-btn .btn.primary, button:has-text("Send OTP")').first().click();
    await expect(page.locator('#sb-toast')).toContainText(/agreement|tick|agree/i);
  });

  test('age range is single-select (clicking one deselects the other)', async ({ page }) => {
    await page.goto('/app.html?mode=app#onboarding-4');
    const screen = activeScreen(page);
    const young = screen.locator('.pill', { hasText: '18 – 35' }).first();
    const older = screen.locator('.pill', { hasText: '36 – 60' }).first();
    await young.click();
    await older.click();
    await expect(older).toHaveClass(/\bon\b/);
    await expect(young).not.toHaveClass(/\bon\b/);
  });

  test('crops are multi-select (clicking toggles independently)', async ({ page }) => {
    await page.goto('/app.html?mode=app#onboarding-4');
    const screen = activeScreen(page);
    const hass = screen.locator('.pill', { hasText: 'Hass' }).first();
    const cassava = screen.locator('.pill', { hasText: 'Cassava' }).first();
    await hass.click();
    await cassava.click();
    await expect(hass).toHaveClass(/\bon\b/);
    await expect(cassava).toHaveClass(/\bon\b/);
    await hass.click();
    await expect(hass).not.toHaveClass(/\bon\b/);
    await expect(cassava).toHaveClass(/\bon\b/); // still on
  });

  test('invalid OTP shows error toast', async ({ page }) => {
    await fillFarmerSignup(page, {
      email: testEmail,
      name: 'Andrew QA',
      phone: '712345678',
      district: 'Mpigi',
      subCounty: 'Nkozi',
      farmSize: '1 acre',
      village: 'Kayabwe',
      ageRange: '18 – 35',
      crops: ['Maize'],
    });
    // Generate but don't use a real OTP — type a wrong one
    await generateOtp(testEmail); // ensures user exists
    await typeOtpAndVerify(page, '000000');
    await expect(page.locator('#sb-toast')).toContainText(/invalid|expired/i);
  });

  // The "signup with EXISTING email overwrites" behavior depends on the
  // app's verifyOtp handler reading IIFE-scoped pendingName/pendingRole vars
  // that were set when the user clicked Send OTP the second time (see
  // app.html line ~11477). Replicating that path in a test requires either:
  //   (a) clicking the real Send-OTP button twice for the same email, which
  //       Supabase blocks for 60s per email (test would need a 65s wait), OR
  //   (b) exposing pendingName/pendingRole on window so tests can prime them.
  // Until one of those is in place, run this scenario manually — the app
  // logic is correct, but automating it under the rate limit is brittle.
  test.skip('signup with email of EXISTING user overwrites with new data', async ({ page }) => {
    await signUpAsFarmer(page, {
      email: testEmail, name: 'Original Name', phone: '712345678',
      district: 'Mpigi', subCounty: 'Nkozi', farmSize: '0.5 acres', village: 'V1',
      ageRange: '18 – 35', crops: ['Matooke'],
    });
    await page.evaluate(() => { try { localStorage.clear(); sessionStorage.clear(); } catch(_) {} });
    await page.waitForTimeout(65_000); // outwait Supabase per-email rate limit
    await signUpAsFarmer(page, {
      email: testEmail, name: 'Updated Name', phone: '712999888',
      district: 'Wakiso', subCounty: 'Central', farmSize: '2 acres', village: 'V2',
      ageRange: '36 – 60', crops: ['Coffee'],
    });
    await expect(activeScreen(page).locator('.greet .name').first()).toContainText('Updated');
  });

});
