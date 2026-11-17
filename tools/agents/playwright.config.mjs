import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 90000,
  expect: { timeout: 60000 },
  retries: process.env.CI ? 1 : 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: process.env.FREEWAY_QA_URL || 'http://127.0.0.1:8080',
    launchOptions: process.env.FREEWAY_CHROMIUM_PATH ? { executablePath: process.env.FREEWAY_CHROMIUM_PATH } : {},
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  webServer: process.env.FREEWAY_QA_URL ? undefined : {
    command: 'python3 -m http.server 8080 --bind 127.0.0.1 --directory ../../build/web',
    url: 'http://127.0.0.1:8080',
    reuseExistingServer: !process.env.CI,
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['Pixel 7'] } },
  ],
});
