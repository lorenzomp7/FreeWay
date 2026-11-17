import { test, expect } from '@playwright/test';

// Non crea account e non scrive segnalazioni sul database condiviso.
test('accesso visibile e utilizzabile con tastiera e schermo piccolo', async ({ page }) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('/');
  await expect(page.getByRole('button', { name: 'Continua come ospite' })).toBeVisible();
  const email = page.getByRole('textbox', { name: /email/i });
  await expect(email).toBeVisible();
  await email.fill('qa@example.invalid');
  await expect(email).toHaveValue('qa@example.invalid');
  await email.press('Tab');
  await expect(email).not.toBeFocused();
  const guest = page.getByRole('button', { name: 'Continua come ospite' });
  const box = await guest.boundingBox();
  expect(box).not.toBeNull();
  expect(box.x).toBeGreaterThanOrEqual(0);
  expect(box.x + box.width).toBeLessThanOrEqual(page.viewportSize().width + 1);
  expect(errors).toEqual([]);
});
