// Evaluates one expression in the app's WebView through the DevTools protocol
// (debug builds expose it) and prints the value. Promises are awaited.
// Usage: node devtools-eval.mjs <port> '<expression>'
const [port = '9222', expression = 'location.href'] = process.argv.slice(2);
const pages = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
const page = pages.find((p) => p.type === 'page' && /thabangvision\.com/.test(p.url)) || pages.find((p) => p.type === 'page');
if (!page) { console.log(JSON.stringify({ error: 'no page' })); process.exit(0); }
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
ws.send(JSON.stringify({ id: 1, method: 'Runtime.evaluate', params: { expression, returnByValue: true, awaitPromise: true, userGesture: true } }));
const msg = await new Promise((r) => { ws.onmessage = (e) => { const d = JSON.parse(e.data); if (d.id === 1) r(d); }; });
const v = msg.result?.result?.value;
console.log(typeof v === 'string' ? v : JSON.stringify(msg.result?.exceptionDetails?.exception?.description ?? msg.result ?? msg));
ws.close();
