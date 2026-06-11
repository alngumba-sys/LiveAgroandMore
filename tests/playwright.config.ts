import { defineConfig, devices } from '@playwright/test';
import * as dotenv from 'dotenv';

dotenv.config();

/**
 * Playwright config for Agro and More.
 *
 * Two projects:
 *   - "mobile-chrome" runs the PWA at agro-more-app.netlify.app in a phone-sized viewport.
 *   - "admin-desktop" runs the admin platform at agroandmorehub.com in a desktop viewport.
 *
 * `webServer` is intentionally NOT used — we run against live deploys.
 */
export default defineConfig({
  testDir: '.',
  /* Maximum time one test can run for. */
  timeout: 60_000,
  /* Each assertion will retry for up to this duration. */
  expect: { timeout: 8_000 },
  fullyParallel: false, // serialize so cleanup is predictable
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1, // single-worker so we don't blow through Supabase auth rate limits
  reporter: [
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    ['list'],
  ],
  use: {
    actionTimeout: 10_000,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'mobile-chrome',
      testMatch: /mobile\/.*\.spec\.ts/,
      use: {
        ...devices['Pixel 7'],
        baseURL: process.env.MOBILE_URL || 'https://agro-more-app.netlify.app',
      },
    },
    {
      name: 'admin-desktop',
      testMatch: /admin\/.*\.spec\.ts/,
      use: {
        ...devices['Desktop Chrome'],
        baseURL: process.env.ADMIN_URL || 'https://agroandmorehub.com',
      },
    },
  ],
});
