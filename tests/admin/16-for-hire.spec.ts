/**
 * For Hire Providers — tractor/water-pump/thresher operators.
 * TODO: add provider, set availability, verify mobile "Hire" tile shows them.
 */
import { test, expect } from '@playwright/test';
import { adminSignIn, adminNav } from '../helpers/admin-auth';

test('for-hire providers page loads', async ({ page }) => {
  const errs: string[] = [];
  page.on('pageerror', e => errs.push(e.message));
  await adminSignIn(page);
  await adminNav(page, 'forhire');
  await page.waitForTimeout(2000);
  expect(errs).toEqual([]);
});
