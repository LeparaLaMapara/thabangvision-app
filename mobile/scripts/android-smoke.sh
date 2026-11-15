#!/usr/bin/env bash
# Android emulator smoke test, run from mobile/ inside the emulator runner.
# Installs the debug APK, launches it, waits for the site to load, and checks
# the app is still the focused window (no crash). Saves a screenshot, the
# focused window and the app's log lines to smoke-android/.
set -uo pipefail
APP_ID="${APP_ID:-com.thabangvision.app}"
OUT=smoke-android
mkdir -p "$OUT"
APK=$(ls android/app/build/outputs/apk/debug/*.apk | head -1)

adb wait-for-device
adb install -r "$APK"
adb logcat -c
adb shell am start -W -n "$APP_ID/.MainActivity"
sleep 25

adb exec-out screencap -p > "$OUT/launch.png"
adb shell dumpsys window | grep -E 'mCurrentFocus|mFocusedApp' > "$OUT/focus.txt" || true
adb logcat -d | grep -iE "capacitor|chromium|$APP_ID|AndroidRuntime" > "$OUT/logcat.txt" || true
PID=$(adb shell pidof "$APP_ID" | tr -d '\r')

echo "pid: ${PID:-none}"
cat "$OUT/focus.txt"
if [ -z "$PID" ]; then echo "FAIL: app is not running"; exit 1; fi
if grep -q "FATAL EXCEPTION" "$OUT/logcat.txt"; then echo "FAIL: crash in log"; exit 1; fi
if ! grep -q "$APP_ID" "$OUT/focus.txt"; then echo "FAIL: app is not the focused window"; exit 1; fi

# The live site rendered inside the app (not the offline page or the site's
# error screen): read the page through the WebView's DevTools socket. The
# emulator's network can come up after the first load, so try three times,
# relaunching the app in between.
OK=0
for TRY in 1 2 3; do
  PID=$(adb shell pidof "$APP_ID" | tr -d '\r')
  adb forward --remove-all >/dev/null 2>&1 || true
  adb forward tcp:9222 "localabstract:webview_devtools_remote_${PID}" >/dev/null 2>&1 || true
  node scripts/devtools-text.mjs 9222 > "$OUT/page.json" 2>&1 || true
  echo "try $TRY: $(cat "$OUT/page.json")"
  if grep -q '"href":"https://www.thabangvision.com' "$OUT/page.json" && ! grep -qiE "couldn.t load" "$OUT/page.json"; then OK=1; break; fi
  adb shell am force-stop "$APP_ID"; sleep 3
  adb shell am start -W -n "$APP_ID/.MainActivity" >/dev/null; sleep 30
done
adb exec-out screencap -p > "$OUT/launch.png"
if [ "$OK" != 1 ]; then echo "FAIL: the live site did not render"; exit 1; fi
echo "site rendered: yes"

# Back button: Capacitor should handle it without closing to a crash.
adb shell input keyevent KEYCODE_BACK
sleep 3
adb exec-out screencap -p > "$OUT/after-back.png"
echo "PASS: installed, launched, focused, no crash"
