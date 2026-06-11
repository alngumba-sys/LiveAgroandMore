/**
 * Field Officers — load + tab switching.
 * TODO: assign officer to district, view their farm_visits, approve verified status.
 */
import { test, expect } from '@playwright/test';
import { adminSignIn, adminNav } from '../helpers/admin-auth';

test('field officers page loads', async ({ page }) => {
  const errs: string[] = [];
  page.on('pageerror', e => errs.push(e.message));
  await adminSignIn(page);
  await adminNav(page, 'officers');
  await page.waitForTimeout(2000);
  expect(errs).toEqual([]);
});
