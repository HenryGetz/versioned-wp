import { expect, test } from '@playwright/test';

// Replace CHANGEME placeholders during setup.
const BASE_URL = 'https://CHANGEME-staging-url';
const THEME_SLUG = 'CHANGEME-theme-slug';
const LOCAL_URL_MARKER = 'CHANGEME-local-url';
const STAGING_HOST = new URL(BASE_URL).host;

function normalizeResourceUrl(url: string): string | null {
  if (!url) return null;
  if (url.startsWith('data:') || url.startsWith('blob:') || url.startsWith('mailto:') || url.startsWith('tel:')) {
    return null;
  }
  return new URL(url, BASE_URL).toString();
}

async function assertHead200(request: import('@playwright/test').APIRequestContext, urls: string[], kind: string) {
  const failures: string[] = [];

  for (const url of urls) {
    const response = await request.fetch(url, { method: 'HEAD' });
    if (response.status() !== 200) {
      failures.push(`${kind} ${url} -> ${response.status()}`);
    }
  }

  expect(
    failures,
    failures.length ? `Broken ${kind} resources:\n${failures.join('\n')}` : `All ${kind} resources returned HTTP 200`,
  ).toHaveLength(0);
}

test('a. Home page renders real content', async ({ page }) => {
  const response = await page.goto('/');
  expect(response?.status()).toBe(200);

  await expect(page).toHaveTitle(/.+/);

  const bodyClass = (await page.locator('body').getAttribute('class')) ?? '';
  expect(bodyClass).toContain(THEME_SLUG);

  await expect(page.locator('.wp-block-navigation').first()).toBeVisible();

  const hasImageFromSite = await page.locator(`img[src*="${STAGING_HOST}"]`).count();
  expect(hasImageFromSite).toBeGreaterThan(0);

  const leakedUrlCount = await page
    .locator(
      `[href*="${LOCAL_URL_MARKER}"], [src*="${LOCAL_URL_MARKER}"], [href*="localhost"], [src*="localhost"], [href*="127.0.0.1"], [src*="127.0.0.1"], [href*="lndo.site"], [src*="lndo.site"]`,
    )
    .count();
  expect(leakedUrlCount).toBe(0);

  const siteBlocksText = ((await page.locator('.wp-site-blocks').first().innerText()) || '').trim();
  expect(siteBlocksText.length).toBeGreaterThan(20);

  await page.screenshot({ path: 'tests/staging/screenshots/home.png', fullPage: true });
});

test('b. All published pages render (not 404)', async ({ page, request }) => {
  const apiResponse = await request.get('/wp-json/wp/v2/pages?per_page=100&status=publish');
  expect(apiResponse.status()).toBe(200);

  const pages = (await apiResponse.json()) as Array<{ title?: { rendered?: string }; link?: string }>;
  expect(pages.length).toBeGreaterThan(0);

  const failures: string[] = [];

  for (const wpPage of pages) {
    const title = wpPage.title?.rendered ?? '(untitled)';
    const link = wpPage.link;
    if (!link) {
      failures.push(`${title} -> missing link`);
      continue;
    }

    const response = await page.goto(link, { waitUntil: 'domcontentloaded' });
    const status = response?.status() ?? 0;
    if (status !== 200) {
      failures.push(`${title} -> ${link} -> HTTP ${status}`);
      continue;
    }

    const visibleTextLength = (await page.locator('body').innerText()).replace(/\s+/g, ' ').trim().length;
    if (visibleTextLength < 30) {
      failures.push(`${title} -> ${link} -> insufficient visible body content`);
    }
  }

  expect(
    failures,
    failures.length ? `Published pages failing render checks:\n${failures.join('\n')}` : 'All published pages rendered with status 200',
  ).toHaveLength(0);
});

test('c. All images load', async ({ page, request }) => {
  await page.goto('/');

  const imgUrls = await page.evaluate(() =>
    Array.from(document.querySelectorAll('img[src]')).map((img) => (img as HTMLImageElement).src),
  );
  const unique = Array.from(new Set(imgUrls.map(normalizeResourceUrl).filter((u): u is string => Boolean(u))));

  expect(unique.length).toBeGreaterThan(0);
  await assertHead200(request, unique, 'image');
});

test('d. All CSS and JS load', async ({ page, request }) => {
  await page.goto('/');

  const assets = await page.evaluate(() => {
    const css = Array.from(document.querySelectorAll('link[rel="stylesheet"][href]')).map(
      (el) => (el as HTMLLinkElement).href,
    );
    const js = Array.from(document.querySelectorAll('script[src]')).map((el) => (el as HTMLScriptElement).src);
    return { css, js };
  });

  const cssUrls = Array.from(new Set(assets.css.map(normalizeResourceUrl).filter((u): u is string => Boolean(u))));
  const jsUrls = Array.from(new Set(assets.js.map(normalizeResourceUrl).filter((u): u is string => Boolean(u))));

  expect(cssUrls.length).toBeGreaterThan(0);
  expect(jsUrls.length).toBeGreaterThan(0);

  await assertHead200(request, cssUrls, 'css');
  await assertHead200(request, jsUrls, 'js');
});

test('e. No mixed content or local URL leakage', async ({ page }) => {
  await page.goto('/');

  const html = await page.content();
  expect(html).not.toContain(LOCAL_URL_MARKER);
  expect(html).not.toMatch(/\.lndo\.site/i);
  expect(html).not.toMatch(/http:\/\/127\.0\.0\.1/i);
  expect(html).not.toMatch(/http:\/\/localhost/i);

  const mixedContent = await page.evaluate(() => {
    const urls = [
      ...Array.from(document.querySelectorAll('link[rel="stylesheet"][href]')).map((el) =>
        (el as HTMLLinkElement).href,
      ),
      ...Array.from(document.querySelectorAll('script[src]')).map((el) => (el as HTMLScriptElement).src),
    ];
    return urls.filter((url) => url.startsWith('http://'));
  });

  expect(mixedContent, mixedContent.length ? `Mixed-content assets found:\n${mixedContent.join('\n')}` : undefined).toHaveLength(
    0,
  );
});

test('f. Navigation links work', async ({ page }) => {
  await page.goto('/');

  const navLinks = await page.evaluate(() => {
    const hrefs = Array.from(document.querySelectorAll('.wp-block-navigation a[href]')).map((a) =>
      (a as HTMLAnchorElement).getAttribute('href') || '',
    );
    return Array.from(new Set(hrefs.filter(Boolean)));
  });

  expect(navLinks.length).toBeGreaterThan(0);

  const failures: string[] = [];
  const testPage = await page.context().newPage();

  for (const href of navLinks) {
    if (!href.startsWith(BASE_URL) && !href.startsWith('/')) {
      failures.push(`Unexpected nav href format: ${href}`);
      continue;
    }
    const url = new URL(href, BASE_URL).toString();
    const response = await testPage.goto(url, { waitUntil: 'domcontentloaded' });
    const status = response?.status() ?? 0;
    if (status !== 200) {
      failures.push(`${href} -> HTTP ${status}`);
    }
  }

  await testPage.close();

  expect(
    failures,
    failures.length ? `Navigation link failures:\n${failures.join('\n')}` : 'All navigation links returned HTTP 200',
  ).toHaveLength(0);
});

test('g. Mobile responsive', async ({ browser }) => {
  const context = await browser.newContext({ viewport: { width: 375, height: 812 } });
  const page = await context.newPage();

  const response = await page.goto('/');
  expect(response?.status()).toBe(200);

  const hasHorizontalOverflow = await page.evaluate(
    () => document.documentElement.scrollWidth > document.documentElement.clientWidth,
  );
  await page.screenshot({ path: 'tests/staging/screenshots/home-mobile.png', fullPage: true });
  expect(hasHorizontalOverflow).toBe(false);
  await context.close();
});

test('h. wp-admin is accessible', async ({ page }) => {
  const response = await page.goto('/wp-admin/');
  expect(response?.status()).toBe(200);
  await expect(page.locator('input[name="log"]').first()).toBeVisible();
});
