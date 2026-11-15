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

# The live site rendered inside the app (not the offline page): the WebView's
# accessibility tree carries the page text.
adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || true
adb pull /sdcard/ui.xml "$OUT/ui.xml" >/dev/null 2>&1 || true
if grep -qiE "Rentals|Studio|Book" "$OUT/ui.xml" 2>/dev/null; then echo "site rendered: yes"; else echo "FAIL: the live site did not render (offline page or blank)"; exit 1; fi

# Back button: Capacitor should handle it without closing to a crash.
adb shell input keyevent KEYCODE_BACK
sleep 3
adb exec-out screencap -p > "$OUT/after-back.png"
echo "PASS: installed, launched, focused, no crash"
