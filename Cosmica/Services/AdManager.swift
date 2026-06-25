import Foundation
import Observation
import UIKit
import GoogleMobileAds

/// Thin wrapper around Google Mobile Ads. All three ad formats are exposed:
/// - Banner: shown in `ObservatoryView` bottom area (gated by `removeAdsOwned`).
/// - Rewarded: player-initiated from `ShopView` (always available, even with removeAds).
/// - Interstitial: shown after Big Bang, rate-limited to 1 per 3 min (gated).
///
/// Ad unit IDs default to Google's test IDs. Replace with real ones before App Store submission.
@MainActor
@Observable
final class AdManager: NSObject {
    // Test IDs (safe to ship; Google won't pay for them) — REPLACE FOR PRODUCTION.
    static let testBannerUnitId       = "ca-app-pub-3940256099942544/2934735716"
    static let testRewardedUnitId     = "ca-app-pub-3940256099942544/1712485313"
    static let testInterstitialUnitId = "ca-app-pub-3940256099942544/4411468910"

    var bannerUnitId       = AdManager.testBannerUnitId
    var rewardedUnitId     = AdManager.testRewardedUnitId
    var interstitialUnitId = AdManager.testInterstitialUnitId

    private(set) var removeAdsOwned: Bool = false
    private(set) var rewardedReady: Bool = false
    private(set) var interstitialReady: Bool = false

    private var rewardedAd: RewardedAd?
    private var interstitialAd: InterstitialAd?
    private var lastInterstitialShownAt: Date?
    private let interstitialMinInterval: TimeInterval = 180  // 3 min

    func configure(removeAdsOwned: Bool) {
        self.removeAdsOwned = removeAdsOwned
        Task {
            await loadRewarded()
            if !removeAdsOwned { await loadInterstitial() }
        }
    }

    // MARK: - Rewarded

    func loadRewarded() async {
        do {
            let ad = try await RewardedAd.load(with: rewardedUnitId, request: Request())
            rewardedAd = ad
            rewardedReady = true
        } catch {
            rewardedReady = false
            print("[AdManager] Rewarded load failed: \(error)")
        }
    }

    /// Present the rewarded ad. `onReward` is invoked on successful reward; `onDismiss` is always invoked when the ad closes.
    func showRewarded(from root: UIViewController, onReward: @escaping () -> Void, onDismiss: @escaping () -> Void = {}) {
        guard let ad = rewardedAd else {
            onDismiss()
            Task { await loadRewarded() }
            return
        }
        rewardedReady = false
        ad.present(from: root) {
            onReward()
        }
        // Preload the next one.
        Task {
            await loadRewarded()
            onDismiss()
        }
    }

    // MARK: - Interstitial

    func loadInterstitial() async {
        do {
            let ad = try await InterstitialAd.load(with: interstitialUnitId, request: Request())
            interstitialAd = ad
            interstitialReady = true
        } catch {
            interstitialReady = false
            print("[AdManager] Interstitial load failed: \(error)")
        }
    }

    func showInterstitialIfReady(from root: UIViewController) {
        guard !removeAdsOwned else { return }
        if let last = lastInterstitialShownAt, Date().timeIntervalSince(last) < interstitialMinInterval { return }
        guard let ad = interstitialAd else {
            Task { await loadInterstitial() }
            return
        }
        ad.present(from: root)
        lastInterstitialShownAt = Date()
        interstitialReady = false
        Task { await loadInterstitial() }
    }
}
