/**
 * Admin: Add Product → appears on mobile shop.
 * Cross-system test: hits admin platform AND mobile PWA.
 */
import { test, expect } from '@playwright/test';
import { generateOtp, deleteProductByName, qaProductName, adminClient } from '../helpers/supabase';

const ADMIN_EMAIL = process.env.ADMIN_TEST_EMAIL!;

test.skip(!ADMIN_EMAIL, 'Set ADMIN_TEST_EMAIL in .env to a real admin user to run admin tests.');

async function adminSignIn(page: any) {
  await page.goto('/index.html');
  // Find and click the "Sign in / Login" form
  await page.locator('input[type="email"]').fill(ADMIN_EMAIL);
  await page.locator('button:has-text("Sign in"), button:has-text("Continue"), button[type="submit"]').first().click();
  // Wait for OTP entry, generate code, type it
  await page.waitForSelector('input[type="text"], input.otp-input, input[inputmode="numeric"]', { timeout: 8000 });
  const otp = await generateOtp(ADMIN_EMAIL);
  // Try to find OTP inputs. The admin uses a similar 6-box pattern or a single input.
  const otpInputs = page.locator('input[maxlength="1"], input[inputmode="numeric"]');
  const count = await otpInputs.count();
  if (count >= 6) {
    for (let i = 0; i < 6; i++) await otpInputs.nth(i).fill(otp[i]);
  } else if (count === 1) {
    await otpInputs.first().fill(otp);
  }
  await page.locator('button:has-text("Verify"), button:has-text("Continue")').first().click();
  await page.waitForURL(/admin\.html|dashboard/, { timeout: 15_000 });
}

test.describe('Admin → Add Product → mobile sync', () => {
  let productName: string;

  test.beforeAll(() => { productName = qaProductName(); });

  test.afterEach(async () => {
    if (productName) await deleteProductByName(productName);
  });

  test('admin adds a Fertilizer product and it appears on mobile shop', async ({ page, browser }) => {
    await adminSignIn(page);

    // Navigate to Products page in sidebar
    await page.locator('a:has-text("Products"), text=Products').first().click();
    await page.waitForTimeout(1000);

    // Click + Add Product
    await page.locator('button:has-text("Add Product"), button:has-text("+ Add")').first().click();

    // Fill product form
    await page.locator('#pd-name').fill(productName);
    await page.locator('#pd-category').selectOption({ label: 'Fertilizers' });
    await page.locator('#pd-brand').fill('QA Brand');
    await page.locator('#pd-price').fill('25000');
    await page.locator('#pd-stock').fill('10');

    // Confirm show_on_shop is CHECKED by default (the fix we just made)
    await expect(page.locator('#pd-show-shop')).toBeChecked();

    // Save & Publish
    await page.locator('#pd-save-btn').click();

    // Toast indicates success
    await expect(page.locator('.toast, [class*="toast"]').first()).toContainText(/created|published|success/i, { timeout: 8_000 });

    // Verify product is in DB with show_on_shop=true
    const admin = adminClient();
    const { data: row } = await admin
      .from('products')
      .select('name,category,show_on_shop,status,price_ugx')
      .eq('name', productName)
      .single();
    expect(row?.show_on_shop).toBe(true);
    expect(row?.status).toBe('active');
    expect(row?.category).toBe('Fertilizers');

    // Now open the MOBILE PWA in a separate context and confirm visibility
    const mobileCtx = await browser.newContext({ baseURL: 'https://agro-more-app.netlify.app' });
    const mobile = await mobileCtx.newPage();
    await mobile.goto('/app.html?mode=app#shop-1');
    await mobile.waitForTimeout(2500);
    await mobile.locator('.cat-card').filter({ hasText: 'Fertilizers' }).click();
    await mobile.waitForTimeout(3000);
    await expect(mobile.locator('.product-row').filter({ hasText: productName })).toBeVisible({ timeout: 8_000 });
    await mobileCtx.close();
  });

  test('admin saves as DRAFT — product is NOT visible on mobile', async ({ page, browser }) => {
    await adminSignIn(page);
    await page.locator('a:has-text("Products")').first().click();
    await page.locator('button:has-text("Add Product")').first().click();
    productName = qaProductName('Draft Product');
    await page.locator('#pd-name').fill(productName);
    await page.locator('#pd-category').selectOption({ label: 'Seeds' });
    await page.locator('#pd-price').fill('5000');
    // Click "Save as Draft" — NOT "Save & Publish"
    await page.locator('button:has-text("Save as Draft")').click();
    await expect(page.locator('.toast').first()).toBeVisible({ timeout: 6_000 });

    // Verify status=draft and show_on_shop=false
    const admin = adminClient();
    const { data: row } = await admin.from('products').select('status,show_on_shop')
      .eq('name', productName).single();
    expect(row?.status).toBe('draft');
    expect(row?.show_on_shop).toBe(false);

    // Confirm mobile does NOT show it
    const mobileCtx = await browser.newContext({ baseURL: 'https://agro-more-app.netlify.app' });
    const mobile = await mobileCtx.newPage();
    await mobile.goto('/app.html?mode=app#shop-1');
    await mobile.locator('.cat-card').filter({ hasText: 'Seeds' }).click();
    await mobile.waitForTimeout(3000);
    await expect(mobile.locator('.product-row').filter({ hasText: productName })).toHaveCount(0);
    await mobileCtx.close();
  });
});
