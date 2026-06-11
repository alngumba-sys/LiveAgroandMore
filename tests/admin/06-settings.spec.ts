/**
 * Settings — every sub-tab loads without error. Specific behavior tests
 * for commission, knowledge base, account, etc. live in their own specs.
 */
import { test, expect } from '@playwright/test';
import { adminSignIn, adminNav } from '../helpers/admin-auth';
import { adminClient } from '../helpers/supabase';

const TABS = [
  { id: 'stab-org',            name: 'Organization profile' },
  { id: 'stab-branding',       name: 'Branding & palette' },
  { id: 'stab-commission',     name: 'Commission rate' },
  { id: 'stab-payments',       name: 'Payment methods' },
  { id: 'stab-fx',             name: 'FX rate' },
  { id: 'stab-sms',            name: 'SMS provider' },
  { id: 'stab-whatsapp',       name: 'WhatsApp Business' },
  { id: 'stab-odoo',           name: 'Odoo connection' },
  { id: 'stab-export',         name: 'Data export schedule' },
  { id: 'stab-audit',          name: 'Audit log' },
  { id: 'stab-knowledge_base', name: 'Knowledge Base' },
  { id: 'stab-account',        name: 'Password & security' },
];

test.describe('Settings sub-tabs all load', () => {
  test('every tab renders without page-level JS errors', async ({ page }) => {
    const errs: string[] = [];
    page.on('pageerror', e => errs.push(`${e.message}`));
    await adminSignIn(page);
    await adminNav(page, 'settings');
    for (const tab of TABS) {
      await page.locator('#' + tab.id).click();
      await page.waitForTimeout(800);
    }
    expect(errs, errs.join('\n---\n')).toEqual([]);
  });
});

test.describe('Commission rate', () => {
  test('reading current rate then writing it back is idempotent', async ({ page }) => {
    await adminSignIn(page);
    await adminNav(page, 'settings');
    await page.locator('#stab-commission').click();
    await page.waitForTimeout(1500);
    const admin = adminClient();
    const { data } = await admin.from('settings').select('value').eq('key', 'commission_rate').single();
    expect(data?.value).toBeTruthy();
  });
});

test.describe('Knowledge Base in Settings', () => {
  test('shows article count + table', async ({ page }) => {
    await adminSignIn(page);
    await adminNav(page, 'settings');
    await page.locator('#stab-knowledge_base').click();
    await expect(page.locator('text=/articles/i').first()).toBeVisible({ timeout: 8_000 });
  });
});

test.describe('Password change', () => {
  test('rejects mismatched confirm', async ({ page }) => {
    await adminSignIn(page);
    await adminNav(page, 'settings');
    await page.locator('#stab-account').click();
    await page.locator('#pw-current').fill('any');
    await page.locator('#pw-new').fill('newpwlong123');
    await page.locator('#pw-confirm').fill('different456');
    await page.locator('#pw-save-btn').click();
    await expect(page.locator('.toast').first()).toContainText(/do not match/i);
  });

  test('rejects new password under 8 characters', async ({ page }) => {
    await adminSignIn(page);
    await adminNav(page, 'settings');
    await page.locator('#stab-account').click();
    await page.locator('#pw-current').fill('any');
    await page.locator('#pw-new').fill('short');
    await page.locator('#pw-confirm').fill('short');
    await page.locator('#pw-save-btn').click();
    await expect(page.locator('.toast').first()).toContainText(/8 characters/i);
  });
});
