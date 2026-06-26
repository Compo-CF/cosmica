import Foundation
import Observation
import UIKit
import GoogleMobileAds

/// Thin wrapper around Google Mobile Ads. All three ad formats are exposed:
/// - Banner: shown in `ObservatoryView` bottom area (gated by `removeAdsOwned`).
/// - Rewarded: player-initiated from `ShopView` (always available, even with removeAds).
/// - Interstitial: shown after Big Bang, rate-limited to 1 per 3 min (gated).
///
/// `#if DEBUG` keeps dev builds on Google's test ad units so simulator runs and Xcode
/// debug sessions don't generate impressions / clicks against the real AdMob account.
/// TestFlight and App Store builds use the production IDs.
@MainActor
@Observable
final class AdManager: NSObject {
    // Google test IDs — safe to ship, no real impressions / no payout.
    static let testBannerUnitId       = "ca-app-pub-3940256099942544/2934735716"
    static let testInterstitialUnitId = "ca-app-pub-3940256099942544/4411468910"
    static let testRewardedUnitId     = "ca-app-pub-3940256099942544/1712485313"

    // Production AdMob ad unit IDs — Cosmica account.
    static let prodBannerUnitId       = "ca-app-pub-1927040492403163/1305638533"
    static let prodInterstitialUnitId = "ca-app-pub-1927040492403163/7487903502"
    static let prodRewardedUnitId     = "ca-app-pub-1927040492403163/3548658494"

    #if DEBUG
    var bannerUnitId       = AdManager.testBannerUnitId
    var interstitialUnitId = AdManager.testInterstitialUnitId
    var rewardedUnitId     = AdManager.testRewardedUnitId
    #else
    var bannerUnitId       = AdManager.prodBannerUnitId
    var interstitialUnitId = AdManager.prodInterstitialUnitId
    var rewardedUnitId     = AdManager.prodRewardedUnitId
    #endif

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
