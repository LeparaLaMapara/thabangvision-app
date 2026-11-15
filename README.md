# ThabangVision app

The Android and iPhone apps for [ThabangVision](https://www.thabangvision.com).

The app is a native shell around the live site: it opens www.thabangvision.com, so
every website release reaches the app at once. The shell adds what a browser tab
cannot do well: links that open the app, sign-in through the phone's browser, the
camera for the instant ID check, the back button, a splash screen and an offline page.

- `mobile/`: the Capacitor project (Android in `mobile/android`, iOS in `mobile/ios`).
- `.github/workflows/mobile.yml`: builds a signed test APK, installs it on an Android
  emulator and checks the site loads; on manual runs, builds the iOS app for the
  simulator and checks it launches.

This repository holds no website code and no secrets. The signing key lives in
repository secrets.
