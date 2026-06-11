/**
 * Admin MFA: enrollment in Settings, login challenge, disable.
 *
 * We use the speakeasy lib via dynamic import — install with:
 *   npm install --save-dev speakeasy
 * If speakeasy isn't installed, tests in this file are skipped.
 */
import { test, expect } from '@playwright/test';
import { adminSignIn, ensureAdminAccount, adminNav } from '../helpers/admin-auth';

let speakeasy: any;
try { speakeasy = require('speakeasy'); } catch (_) { /* optional */ }

test.describe('Admin MFA', () => {
  test.skip(!speakeasy, 'Install speakeasy: npm i -D speakeasy');

  test.beforeAll(async () => { await ensureAdminAccount(); });

  test('enroll → verify → see "Two-factor authentication is ON" → disable', async ({ page }) => {
    await adminSignIn(page);
    // adminSignIn already lands on admin.html with APP.profile loaded.
    await adminNav(page, 'settings');
    await page.locator('#stab-account').click();
    await page.locator('#mfa-card').waitFor({ timeout: 8_000 });

    // If already enrolled (from a prior failed run), unenroll first
    const disableBtn = page.locator('#mfa-disable-btn');
    if (await disableBtn.isVisible().catch(() => false)) {
      page.once('dialog', d => d.accept());
      await disableBtn.click();
      await page.waitForTimeout(1500);
    }

    // Start enrollment
    await page.locator('#mfa-enable-btn').click();
    await page.locator('#mfa-verify-code').waitFor({ timeout: 8_000 });

    // Grab the secret from the secret display
    const secret = await page.locator('#mfa-secret-text').textContent();
    expect(secret).toBeTruthy();

    // Generate a fresh TOTP code with speakeasy
    const code = speakeasy.totp({ secret: secret!.trim(), encoding: 'base32' });
    await page.locator('#mfa-verify-code').fill(code);
    await page.locator('#mfa-verify-btn').click();

    // Should show success state
    await expect(page.locator('#mfa-card')).toContainText(/two-factor authentication is on/i, { timeout: 10_000 });

    // Disable so subsequent test runs don't need TOTP
    page.once('dialog', d => d.accept());
    await page.locator('#mfa-disable-btn').click();
    await expect(page.locator('#mfa-card')).toContainText(/enable two-factor/i, { timeout: 8_000 });
  });

  test('invalid TOTP code during enrollment shows error', async ({ page }) => {
    await adminSignIn(page);
    // adminSignIn already lands on admin.html with APP.profile loaded;
    // calling page.goto again races the profile re-load.
    await adminNav(page, 'settings');
    await page.locator('#stab-account').click();
    await page.locator('#mfa-card').waitFor();
    // Skip if already enrolled
    if (await page.locator('#mfa-disable-btn').isVisible().catch(() => false)) {
      page.once('dialog', d => d.accept());
      await page.locator('#mfa-disable-btn').click();
      await page.waitForTimeout(1500);
    }
    await page.locator('#mfa-enable-btn').click();
    await page.locator('#mfa-verify-code').waitFor();
    await page.locator('#mfa-verify-code').fill('000000');
    await page.locator('#mfa-verify-btn').click();
    await expect(page.locator('#mfa-verify-error')).toBeVisible();
  });
});
