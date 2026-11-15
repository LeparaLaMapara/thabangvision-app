import UIKit
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if DEBUG
        // CI smoke test only (launched with TV_SMOKE=1): print what the page holds.
        if ProcessInfo.processInfo.environment["TV_SMOKE"] == "1" {
            for delay in [12.0, 24.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { AppDelegate.probePage(delay) }
            }
        }
        #endif
        return true
    }

    #if DEBUG
    private static func probePage(_ at: Double) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let root = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
        guard let bridge = root as? CAPBridgeViewController, let web = bridge.webView else {
            print("TV_PROBE \(at)s: no bridge view controller")
            return
        }
        let js = """
        JSON.stringify({ href: location.href, ready: document.readyState, title: document.title,
          textLen: (document.body && document.body.innerText || '').length,
          text: (document.body && document.body.innerText || '').replace(/\\s+/g, ' ').slice(0, 160),
          bodyOpacity: document.body ? getComputedStyle(document.body).opacity : null,
          firstOpacity: document.body && document.body.firstElementChild ? getComputedStyle(document.body.firstElementChild).opacity : null,
          visibility: document.visibilityState, w: innerWidth, h: innerHeight,
          ua: navigator.userAgent.slice(-40), camera: !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia) })
        """
        web.evaluateJavaScript(js) { result, error in
            print("TV_PROBE \(at)s: \(result ?? "nil") \(error.map { "error: \($0)" } ?? "")")
        }
    }
    #endif

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration",
                                          sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
