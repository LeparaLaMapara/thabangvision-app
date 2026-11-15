// Loads www.thabangvision.com in WebKit with the iPhone app's user agent and a
// stand-in Capacitor bridge, and prints any JavaScript error. Exit 1 on error.
const { webkit } = require('playwright');
(async () => {
  const b = await webkit.launch();
  const ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 ThabangVisionApp/ios';
  const errs = [];
  for (const withBridge of [false, true]) {
    const ctx = await b.newContext({ userAgent: ua, viewport: { width: 390, height: 844 }, isMobile: true });
    if (withBridge) await ctx.addInitScript(() => {
      const plugin = { addListener: () => Promise.resolve({ remove: () => Promise.resolve() }), getLaunchUrl: () => Promise.resolve({}) };
      window.Capacitor = { isNativePlatform: () => true, getPlatform: () => 'ios', Plugins: { App: plugin, Browser: { open: () => Promise.resolve() } } };
    });
    const p = await ctx.newPage();
    p.on('pageerror', (e) => errs.push(`[${withBridge ? 'bridge' : 'no bridge'}] ${e.message}\n${(e.stack || '').split('\n').slice(0, 4).join('\n')}`));
    p.on('console', (m) => { if (m.type() === 'error') errs.push(`[${withBridge ? 'bridge' : 'no bridge'}] console: ${m.text().slice(0, 300)}`); });
    for (const path of ['/', '/login', '/rentals']) {
      await p.goto('https://www.thabangvision.com' + path, { waitUntil: 'networkidle', timeout: 60000 }).catch((e) => errs.push('goto ' + path + ': ' + e.message));
      await p.waitForTimeout(3000);
      const text = (await p.locator('body').innerText().catch(() => '')).replace(/\s+/g, ' ').slice(0, 120);
      console.log(`${withBridge ? 'bridge' : 'no bridge'} ${path}: ${text}`);
    }
    await ctx.close();
  }
  await b.close();
  if (errs.length) { console.log('ERRORS:\n' + errs.join('\n')); process.exit(1); }
  console.log('No JavaScript errors.');
})();
