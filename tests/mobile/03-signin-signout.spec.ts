/**
 * Sign-in for returning users + sign-out flow.
 */
import { test, expect } from '@playwright/test';
import { seedSignedInFarmer, signInExisting, cleanupTestUser, activeScreen } from '../helpers/auth';
import { qaEmail } from '../helpers/supabase';

test.describe('Sign-in / sign-out', () => {
  let email: string;

  test.beforeEach(async ({ page }) => {
    email = qaEmail();
    // Pre-create a user so we have someone to sign in as
    await seedSignedInFarmer(page, {
      email,
      name: 'Returning User',
      phone: '712111222',
      district: 'Mpigi',
      subCounty: 'Nkozi',
      farmSize: '1 acre',
      village: 'V',
      ageRange: '18 – 35',
      crops: ['Matooke'],
    });
    // Clear session so we can sign back in
    await page.evaluate(() => {
      try { localStorage.clear(); sessionStorage.clear(); } catch(_) {}
    });
  });

  test.afterEach(async () => {
    if (email) await cleanupTestUser(email);
  });

  test('returning user can sign in via Log in link on intro', async ({ page }) => {
    await signInExisting(page, email);
    await expect(activeScreen(page).locator('.greet .name').first()).toContainText('Returning');
  });

  test('sign-out lands on intro screen with Log in link visible', async ({ page }) => {
    await signInExisting(page, email);
    await page.goto('/app.html?mode=app#profile-1');
    page.once('dialog', d => d.accept());
    await activeScreen(page).locator('.set-row.destructive').first().click();
    await page.waitForURL(/#onboarding-2/, { timeout: 8_000 });
    await expect(activeScreen(page).locator('a.signin-link, a:has-text("Log in")').first()).toBeVisible();
  });

  test('after sign-out, attempting to sign back in with same email works', async ({ page }) => {
    await signInExisting(page, email);
    await page.evaluate(() => {
      try { localStorage.clear(); sessionStorage.clear(); } catch(_) {}
    });
    await signInExisting(page, email);
    await expect(activeScreen(page).locator('.greet .name').first()).toContainText('Returning');
  });

  test('signing in with email that does NOT exist shows friendly error', async ({ page }) => {
    const ghost = `ghost-${Date.now()}@example.com`;
    await page.goto('/app.html?mode=app#onboarding-2');
    // Real Log in link carries .signin-link; mockup duplicate has the same text.
    await activeScreen(page).locator('a.signin-link, a:has-text("Log in")').first().click();
    await page.locator('#sb-li-email').fill(ghost);
    await page.locator('#sb-li-btn').click();
    // Should show friendly toast (the exact wording depends on
    // friendlyAuthError mapping — we just require it's not the raw
    // Supabase "Signups not allowed" message).
    await expect(page.locator('#sb-toast')).toBeVisible({ timeout: 5_000 });
    const txt = await page.locator('#sb-toast').textContent();
    expect(txt?.toLowerCase()).not.toContain('signups not allowed');
  });
});
