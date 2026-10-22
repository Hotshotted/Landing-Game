// Renders icon.svg and tools/splash.html to PNGs: node tools/make_icons.js   (needs playwright + chromium; run from the repo root)
const { chromium } = require('playwright');
const path = require('path');
const root = path.resolve(__dirname, '..');
(async () => {
  const browser = await chromium.launch({ args: ['--no-sandbox', '--allow-file-access-from-files'] });
  const sizes = { 'icons/icon-512.png': 512, 'icons/icon-192.png': 192, 'icons/apple-touch-icon.png': 180 };
  for (const [file, px] of Object.entries(sizes)) {
    const page = await browser.newPage({ viewport: { width: px, height: px } });
    await page.goto('file://' + path.join(root, 'icon.svg'));
    await page.evaluate((n) => { const e = document.documentElement; e.setAttribute('width', n); e.setAttribute('height', n); document.body && (document.body.style.margin = '0'); }, px);
    await page.waitForTimeout(300);
    await page.screenshot({ path: path.join(root, file), omitBackground: true });
    await page.close();
  }
  const sp = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
  await sp.goto('file://' + path.join(root, 'tools/splash.html'));
  await sp.waitForTimeout(800);
  await sp.screenshot({ path: path.join(root, 'assets/splash.png') });
  await browser.close();
})();
