/**
 * Security audit regression tests.
 * Validates fixes from the 2026-05-29 security audit.
 */
import { test, expect } from '@playwright/test';

test.describe('Security audit regressions', () => {

  test('admin dashboard loads without crashing (sbCollapseBtn null guard)', async ({ page }) => {
    // This tests that the sidebar collapse button null guard works.
    // Previously, if #sbCollapseBtn was missing, the whole page would crash.
    await page.goto('/admin.html');
    // Page should at least render the login or dashboard
    await expect(page.locator('body')).toBeVisible();
    // No uncaught errors
    const errors: string[] = [];
    page.on('pageerror', (err) => errors.push(err.message));
    await page.waitForTimeout(2000);
    const crashErrors = errors.filter(e =>
      e.includes('addEventListener') && e.includes('null')
    );
    expect(crashErrors).toHaveLength(0);
  });

  test('password reset page rejects submissions without recovery token', async ({ page }) => {
    // Navigate directly to password-reset without a recovery token
    await page.goto('/password-reset.html');
    await page.fill('#pw1', 'StrongPass123!');
    await page.fill('#pw2', 'StrongPass123!');
    await page.click('#resetBtn');
    // Should show "expired" error since there's no recovery session
    const errEl = page.locator('#resetErr');
    await expect(errEl).toBeVisible({ timeout: 5000 });
    await expect(errEl).toContainText(/expired|request a new one/i);
  });

  test('password reset enforces strength requirements', async ({ page }) => {
    await page.goto('/password-reset.html');
    // Try a weak password (no uppercase, no number)
    await page.fill('#pw1', 'weakpassword');
    await page.fill('#pw2', 'weakpassword');
    await page.click('#resetBtn');
    const errEl = page.locator('#resetErr');
    await expect(errEl).toBeVisible({ timeout: 5000 });
    await expect(errEl).toContainText(/uppercase|number/i);
  });

  test('context menu does not use fn.toString() (XSS prevention)', async ({ page }) => {
    // Load the admin page source and verify the fix is in place
    const response = await page.goto('/admin.html');
    const html = await response?.text() || '';
    // Should NOT contain the old pattern of fn.toString() in onclick
    expect(html).not.toContain('it.fn.toString()');
    // Should contain the new handler registry pattern
    expect(html).toContain('_ctxExec');
    expect(html).toContain('_ctxHandlers');
  });
});
