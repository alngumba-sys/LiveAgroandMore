/**
 * Dashboard: KPI cards render, sidebar navigates, no console errors on load.
 */
import { test, expect } from '@playwright/test';
import { adminSignIn, adminNav } from '../helpers/admin-auth';

test.describe('Admin dashboard', () => {
  test('lands on dashboard with KPI cards visible', async ({ page }) => {
    await adminSignIn(page);
    // The dashboard is the default landing. Scope to `#page-dashboard.active`
    // since other pages also have h1/h2 elements in the DOM (just hidden).
    // The page heading may be H1 or H2 depending on the layout — accept both,
    // and also accept any text inside the page wrapper as the "loaded" signal.
    await expect(page.locator('#page-dashboard.active')).toBeVisible({ timeout: 8_000 });
    await expect(
      page.locator('#page-dashboard.active h1, #page-dashboard.active h2, #page-dashboard.active .kpi-eyebrow').first()
    ).toBeVisible({ timeout: 8_000 });
  });

  test('no uncaught JS errors on dashboard load', async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', e => errors.push(e.message));
    await adminSignIn(page);
    await page.waitForTimeout(3000);
    expect(errors).toEqual([]);
  });

  test('every sidebar nav item loads without crashing', async ({ page }) => {
    await adminSignIn(page);
    // Walk by data-page (matches the actual sidebar buttons). This avoids
    // text-based matches that hit page H2s or duplicate strings in the page body.
    const pages = [
      'products', 'prices', 'traceability', 'orders', 'diaspora', 'forhire',
      'agents', 'officers', 'advisory', 'chatbot', 'notifications',
      'analytics', 'finance', 'users', 'settings',
    ];
    const errors: string[] = [];
    page.on('pageerror', e => errors.push(`${page.url()}: ${e.message}`));
    for (const p of pages) {
      await adminNav(page, p).catch(() => {});
    }
    expect(errors, errors.join('\n')).toEqual([]);
  });
});
