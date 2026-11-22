import { test, expect } from '@playwright/test';

// Non crea account e non scrive segnalazioni sul database condiviso.
test('accesso visibile e utilizzabile con tastiera e schermo piccolo', async ({ page }) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('./');
  // Senza progetto Firebase configurato non ci sono account: si apre subito
  // la mappa, con la ricerca. Non deve mai comparire una pagina di
  // manutenzione.
  const guestButton = page.getByRole('button', { name: 'Continua come ospite' });
  const search = page.getByRole('textbox', { name: /Cerca un luogo/ });
  await expect(guestButton.or(search)).toBeVisible({ timeout: 60000 });
  await expect(page.getByText('manutenzione', { exact: false })).toHaveCount(0);
  if (await search.isVisible()) {
    expect(errors).toEqual([]);
    return;
  }
  await expect(guestButton).toBeVisible();
  const email = page.getByRole('textbox', { name: /email/i });
  await expect(email).toBeVisible();
  // Flutter accetta il testo solo dalla tastiera: fill() lascia il campo vuoto
  // con alcune versioni di Chromium.
  await email.click();
  await email.pressSequentially('qa@example.invalid');
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
