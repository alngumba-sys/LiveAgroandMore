/**
 * Users & Roles — list of staff + farmer/agent/officer/diaspora users.
 * Invite Member already has its own spec (02-invite-member.spec.ts).
 * TODO: deactivate a user, change role, view audit history.
 */
import { test, expect } from '@playwright/test';
import { adminSignIn, adminNav } from '../helpers/admin-auth';

test('users page loads + sub-tabs render', async ({ page }) => {
  const errs: string[] = [];
  page.on('pageerror', e => errs.push(e.message));
  await adminSignIn(page);
  await adminNav(page, 'users');
  await page.waitForTimeout(2000);
  expect(errs).toEqual([]);
});
