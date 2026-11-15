import type { CapacitorConfig } from '@capacitor/cli';

/**
 * ThabangVision for Android and iOS.
 *
 * The app is a native shell around the live site: it loads
 * https://www.thabangvision.com, so every web release reaches the apps the
 * moment it deploys, with no store update. What the shell adds is what a
 * browser tab cannot do well: links that open the app, sign-in through the
 * system browser, the camera for ID checks, the Android back button, a proper splash and status bar, and an offline screen
 * (www/index.html) when there is no signal.
 *
 * appId is permanent once published to either store. Do not change it after
 * the first upload.
 */
const SITE = 'https://www.thabangvision.com';

const config: CapacitorConfig = {
  appId: 'com.thabangvision.app',
  appName: 'ThabangVision',
  // Shown only when the site cannot load (no signal): see www/index.html.
  webDir: 'www',
  server: {
    url: SITE,
    cleartext: false,
    // Pages the app may open inside itself. Everything else (Google sign-in,
    // Paystack's 3-D Secure pages, WhatsApp, maps) opens outside the app,
    // which Google requires for sign-in and which keeps payments in a real
    // browser.
    allowNavigation: ['www.thabangvision.com', 'thabangvision.com', '*.supabase.co'],
    errorPath: 'index.html',
  },
  backgroundColor: '#050505',
  // Web console lines reach the native log in debug builds (CI smoke tests read them).
  loggingBehavior: 'debug',
  android: {
    allowMixedContent: false,
    // The site reads this to know it is inside the app (lib/native/app.ts,
    // NATIVE_APP.userAgentToken in lib/constants.ts). Keep the two in step.
    appendUserAgent: 'ThabangVisionApp/android',
  },
  ios: {
    contentInset: 'never',
    // Needs WKAppBoundDomains in Info.plist (thabangvision.com).
    limitsNavigationsToAppBoundDomains: true,
    appendUserAgent: 'ThabangVisionApp/ios',
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 1200,
      backgroundColor: '#050505',
      showSpinner: false,
    },
    StatusBar: {
      style: 'DARK',
      backgroundColor: '#050505',
      overlaysWebView: false,
    },
  },
};

export default config;
