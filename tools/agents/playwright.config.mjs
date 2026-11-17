import { defineConfig, devices } from '@playwright/test';

// Con la barra finale i percorsi relativi restano dentro un sottopercorso come /FreeWay/.
const qaUrl = process.env.FREEWAY_QA_URL;
const baseURL = qaUrl ? (qaUrl.endsWith('/') ? qaUrl : `${qaUrl}/`) : 'http://127.0.0.1:8080/';

export default defineConfig({
  testDir: './tests',
  timeout: 90000,
  expect: { timeout: 60000 },
  retries: process.env.CI ? 1 : 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL,
    launchOptions: process.env.FREEWAY_CHROMIUM_PATH ? { executablePath: process.env.FREEWAY_CHROMIUM_PATH } : {},
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  webServer: qaUrl ? undefined : {
    command: 'python3 -m http.server 8080 --bind 127.0.0.1 --directory ../../build/web',
    url: 'http://127.0.0.1:8080',
    reuseExistingServer: !process.env.CI,
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['Pixel 7'] } },
  ],
});
