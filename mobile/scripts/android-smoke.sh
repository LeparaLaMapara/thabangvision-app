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

# Signed with the app key (the fingerprint the site's assetlinks.json names),
# so app links and Google sign-in can return to the app.
SIGNER=$(ls -d "$ANDROID_HOME"/build-tools/*/ | sort -V | tail -1)apksigner
CERT=$("$SIGNER" verify --print-certs "$APK" 2>/dev/null | grep -m1 "SHA-256 digest" | awk '{print $NF}')
echo "apk certificate: $CERT"
if [ "$CERT" != "${APP_CERT_SHA256:-}" ]; then echo "FAIL: APK not signed with the app key (expected ${APP_CERT_SHA256:-unset})"; exit 1; fi

# App links verified for www.thabangvision.com, and a site link opens the app.
adb shell pm verify-app-links --re-verify "$APP_ID" >/dev/null 2>&1 || true
sleep 15
adb shell pm get-app-links "$APP_ID" | tee "$OUT/app-links.txt"
if ! grep -q "www.thabangvision.com: verified" "$OUT/app-links.txt"; then echo "FAIL: app links not verified for www.thabangvision.com"; exit 1; fi
adb shell am start -W -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://www.thabangvision.com/rentals" >/dev/null
sleep 10
adb shell dumpsys window | grep -E 'mCurrentFocus' | tee "$OUT/link-focus.txt"
if ! grep -q "$APP_ID" "$OUT/link-focus.txt"; then echo "FAIL: a site link opened outside the app"; exit 1; fi

# The camera works inside the app (the instant ID check needs it), and the
# site sees the app's user agent token.
adb shell pm grant "$APP_ID" android.permission.CAMERA || true
PID=$(adb shell pidof "$APP_ID" | tr -d '\r')
adb forward --remove-all >/dev/null 2>&1 || true
adb forward tcp:9222 "localabstract:webview_devtools_remote_${PID}" >/dev/null 2>&1 || true
UA=$(node scripts/devtools-eval.mjs 9222 'navigator.userAgent')
echo "user agent: $UA"
if ! echo "$UA" | grep -q "ThabangVisionApp/android"; then echo "FAIL: app token missing from the user agent"; exit 1; fi
CAM=$(node scripts/devtools-eval.mjs 9222 'navigator.mediaDevices.getUserMedia({video:true}).then(s=>{const n=s.getVideoTracks().length; s.getTracks().forEach(t=>t.stop()); return "video tracks: "+n}).catch(e=>"camera error: "+e.name+" "+e.message)')
echo "$CAM" | tee "$OUT/camera.txt"
if ! echo "$CAM" | grep -q "video tracks: [1-9]"; then echo "FAIL: the camera did not open inside the app"; exit 1; fi

# Back button: Capacitor should handle it without closing to a crash.
adb shell input keyevent KEYCODE_BACK
sleep 3
adb exec-out screencap -p > "$OUT/after-back.png"
echo "PASS: installed, launched, focused, no crash"
