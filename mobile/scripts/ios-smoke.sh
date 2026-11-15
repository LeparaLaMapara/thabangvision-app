#!/usr/bin/env bash
# iOS simulator smoke test, run from mobile/ on a macOS runner after the
# simulator build. Boots an iPhone simulator, installs and launches the app,
# waits for the site to load, checks the app process is alive, and saves a
# screenshot and the app's log lines to smoke-ios/.
set -uo pipefail
APP_ID="${APP_ID:-com.thabangvision.app}"
OUT=smoke-ios
mkdir -p "$OUT"
APP=$(find ios/App/build/Build/Products/Debug-iphonesimulator -maxdepth 1 -name '*.app' | head -1)
if [ -z "$APP" ]; then echo "FAIL: no .app built"; exit 1; fi

DEVICE=$(xcrun simctl list devices available -j | python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
phones=[x for k,v in d.items() if 'iOS' in k for x in v if x['name'].startswith('iPhone')]
print(phones[-1]['udid'] if phones else '')")
if [ -z "$DEVICE" ]; then echo "FAIL: no iPhone simulator available"; exit 1; fi
xcrun simctl list devices | grep "$DEVICE" | tee "$OUT/device.txt"

xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" "$APP"
# --console-pty keeps the app's stdout, where Capacitor prints the web page's
# console (lines starting with the lightning mark), including JavaScript errors.
( SIMCTL_CHILD_TV_SMOKE=1 xcrun simctl launch --console-pty --terminate-running-process "$DEVICE" "$APP_ID" > "$OUT/console.txt" 2>&1 & )
sleep 40

xcrun simctl io "$DEVICE" screenshot "$OUT/launch.png"
xcrun simctl spawn "$DEVICE" log show --last 2m --predicate "process == \"App\"" > "$OUT/app-log.txt" 2>/dev/null || true
RUNNING=$(xcrun simctl spawn "$DEVICE" launchctl list | grep -c "$APP_ID" || true)

echo "--- page probe ---"
grep -a "TV_PROBE" "$OUT/console.txt" || true
echo "--- web console (errors and warnings) ---"
grep -aE "\[(error|warn)\]|Error|error" "$OUT/console.txt" | head -40 || true
echo "running: $RUNNING"
if [ "$RUNNING" = "0" ]; then echo "FAIL: app is not running after launch"; exit 1; fi
# The live site rendered, not an error screen (the later page probe).
if ! grep -a "TV_PROBE 24" "$OUT/console.txt" | grep -q 'href":"https://www.thabangvision.com'; then echo "FAIL: the site was not on screen at 24 s"; exit 1; fi
if grep -aqE "couldn.t load|Application error" "$OUT/console.txt"; then echo "FAIL: the page showed an error"; exit 1; fi
echo "PASS: installed, launched, still running"
