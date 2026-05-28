/**
 * Security audit regression tests for mobile app.
 * Validates XSS fixes from the 2026-05-29 security audit.
 */
import { test, expect } from '@playwright/test';

test.describe('Mobile security audit regressions', () => {

  test('app.html contains escHtml sanitization function', async ({ page }) => {
    const response = await page.goto('/app.html');
    const html = await response?.text() || '';
    // escHtml should be defined in at least 3 IIFEs (shop, agent/FO, onboarding)
    const matches = html.match(/function escHtml/g) || [];
    expect(matches.length).toBeGreaterThanOrEqual(3);
  });

  test('product names are escaped in shop innerHTML', async ({ page }) => {
    const response = await page.goto('/app.html');
    const html = await response?.text() || '';
    // The product row rendering should use escHtml(p.name)
    expect(html).toContain('escHtml(p.name)');
    expect(html).toContain('escHtml(p.brand)');
    expect(html).toContain('escHtml(p.category)');
  });

  test('cart item names are escaped', async ({ page }) => {
    const response = await page.goto('/app.html');
    const html = await response?.text() || '';
    expect(html).toContain('escHtml(item.name)');
  });

  test('order product_name is escaped', async ({ page }) => {
    const response = await page.goto('/app.html');
    const html = await response?.text() || '';
    expect(html).toContain('escHtml(item.product_name)');
  });

  test('service worker returns 504 for failed non-HTML asset requests', async ({ page }) => {
    // Fetch the service worker source and verify the fix
    const response = await page.goto('/service-worker.js');
    const js = await response?.text() || '';
    // Non-HTML asset fallback should return 504, not index.html
    expect(js).toContain('504');
    expect(js).toContain("statusText: 'Offline'");
  });

  test('cartTotal is NaN-safe', async ({ page }) => {
    const response = await page.goto('/app.html');
    const html = await response?.text() || '';
    // cartTotal should use parseFloat/parseInt for safety
    expect(html).toContain('parseFloat(i.price)');
    expect(html).toContain('parseInt(i.qty)');
  });
});
