import UIKit
import GoogleMobileAds

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Cap ad content to a rating suitable for a general-audience idle
        // game. Without this, AdMob's default targeting can serve adult/
        // dating/suggestive creative. Must be set before start() — applies
        // to every ad request (banner, rewarded, interstitial) for the
        // lifetime of the process.
        MobileAds.shared.requestConfiguration.maxAdContentRating = .general
        // v3.1.2 — the SDK is no longer started here. AdManager.startAfterConsent() starts it
        // once Google's consent flow (ConsentManager) says ads may be requested.
        return true
    }
}
