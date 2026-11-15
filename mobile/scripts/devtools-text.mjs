// Reads the visible text of the app's WebView through the DevTools protocol
// (debug builds expose it). Usage: node devtools-text.mjs <port>. Prints JSON.
const port = process.argv[2] || '9222';
const pages = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
const page = pages.find((p) => p.type === 'page' && /thabangvision\.com/.test(p.url)) || pages.find((p) => p.type === 'page');
if (!page) { console.log(JSON.stringify({ error: 'no page', pages: pages.map((p) => p.url) })); process.exit(0); }
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
ws.send(JSON.stringify({ id: 1, method: 'Runtime.evaluate', params: { expression: "JSON.stringify({href: location.href, text: document.body.innerText.replace(/\\s+/g,' ').slice(0,300)})", returnByValue: true } }));
const msg = await new Promise((r) => { ws.onmessage = (e) => r(JSON.parse(e.data)); });
console.log(msg.result?.result?.value ?? JSON.stringify(msg));
ws.close();
