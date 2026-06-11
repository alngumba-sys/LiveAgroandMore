/**
 * Admin authentication: password login, password reset, logout, session
 * persistence. MFA flow is in 01-mfa.spec.ts.
 */
import { test, expect } from '@playwright/test';
import {
  adminSignIn, ensureAdminAccount,
  ADMIN_TEST_EMAIL, ADMIN_TEST_PASSWORD
} from '../helpers/admin-auth';

test.describe('Admin auth', () => {
  test.beforeAll(async () => { await ensureAdminAccount(); });

  test('login screen renders, accepts credentials, lands on admin.html', async ({ page }) => {
    await page.goto('/index.html');
    await expect(page.locator('input[type="email"], #emailInput').first()).toBeVisible();
    await expect(page.locator('input[type="password"], #passwordInput').first()).toBeVisible();
    await adminSignIn(page);
    await expect(page).toHaveURL(/admin\.html/);
  });

  test('wrong password shows clear error toast', async ({ page }) => {
    await page.goto('/index.html');
    await page.locator('#emailInput').fill(ADMIN_TEST_EMAIL);
    await page.locator('#passwordInput').fill('definitely-wrong-password');
    await page.locator('#loginBtn').click();
    await expect(page.locator('#loginError')).toContainText(/incorrect|invalid/i, { timeout: 6_000 });
  });

  test('empty form shows validation error', async ({ page }) => {
    await page.goto('/index.html');
    await page.locator('#loginBtn').click();
    await expect(page.locator('#loginError')).toContainText(/email|password/i);
  });

  test('forgot password sends reset email (UI confirmation only)', async ({ page }) => {
    await page.goto('/index.html');
    await page.locator('#emailInput').fill(ADMIN_TEST_EMAIL);
    await page.locator('a:has-text("Forgot"), button:has-text("Forgot")').first().click();
    await expect(page.locator('#loginError')).toContainText(/reset/i, { timeout: 6_000 });
  });

  test('session persists across reloads', async ({ page }) => {
    await adminSignIn(page);
    await page.reload();
    await expect(page).toHaveURL(/admin\.html/);
    // Side check: a known admin element should still be present after reload
    await expect(page.locator('body')).not.toContainText('Sign in');
  });

  test('logout clears session and returns to login screen', async ({ page }) => {
    await adminSignIn(page);
    // Trigger the same signOut helper used in the app
    await page.evaluate(() => (window as any).sb?.auth?.signOut?.());
    await page.goto('/admin.html');
    await expect(page).toHaveURL(/index\.html|\/$/);
  });

  test('typing email but not password then submitting blocks request', async ({ page }) => {
    await page.goto('/index.html');
    await page.locator('#emailInput').fill(ADMIN_TEST_EMAIL);
    await page.locator('#loginBtn').click();
    await expect(page.locator('#loginError')).toBeVisible();
  });
});
