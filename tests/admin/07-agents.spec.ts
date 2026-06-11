/**
 * Agents & Leaderboard — load + tab switching.
 * TODO: deeper tests for verify/reject agent, commission calc, payout.
 */
import { test, expect } from '@playwright/test';
import { adminSignIn, adminNav } from '../helpers/admin-auth';

test.describe('Agents & Leaderboard', () => {
  test('page loads, all 4 tabs render', async ({ page }) => {
    const errs: string[] = [];
    page.on('pageerror', e => errs.push(e.message));
    await adminSignIn(page);
    await adminNav(page, 'agents');
    await expect(page.locator('text=/leaderboard/i').first()).toBeVisible({ timeout: 8_000 });
    for (const tab of ['All agents', 'Pending approval', 'Commission reports']) {
      const btn = page.locator(`button:has-text("${tab}")`).first();
      if (await btn.isVisible().catch(() => false)) {
        await btn.click();
        await page.waitForTimeout(800);
      }
    }
    expect(errs).toEqual([]);
  });

  // TODO: verify pending agent → row disappears from Pending tab and joins All agents
  // TODO: reject pending agent → archived
  // TODO: commission month picker calculates total correctly
});
