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

    /// v3.1.2 — false until the consent flow allows ads; nothing is requested before then
    /// (BannerAdSlot also waits on this, since a banner loads itself when it appears).
    private(set) var sdkStarted = false

    /// v3.2 — called with `true` as a full-screen ad opens and `false` when it
    /// closes (or fails to show), so the music can step aside. Set by CosmicaApp.
    @ObservationIgnored var onFullScreenAd: ((Bool) -> Void)?
    @ObservationIgnored private let adWatcher = FullScreenAdWatcher()

    /// `then` runs when the ad really closes (or fails to show), after the music is back.
    private func watchFullScreenAd(then: (() -> Void)? = nil) {
        adWatcher.onDismiss = { [weak self] in
            self?.onFullScreenAd?(false)
            then?()
        }
        onFullScreenAd?(true)
    }

    // v3.4.1 — a loaded rewarded ad is kept until it's used or goes stale.
    // `configure` runs on every foreground and used to throw away a good ad
    // and request a new one, leaving the buttons on "Loading…" for a while;
    // AdMob also expires a loaded ad after an hour, and showing an expired
    // one fails. ShopStats (Nov 2026): about half of Watch Ad taps paid out.
    private var rewardedLoadedAt: Date?
    private var rewardedLoading = false
    private var interstitialLoadedAt: Date?
    /// Replace a loaded ad older than this (AdMob's limit is 60 minutes).
    static let maxAdAge: TimeInterval = 55 * 60

    private func isFresh(_ loadedAt: Date?) -> Bool {
        guard let loadedAt else { return false }
        return Date().timeIntervalSince(loadedAt) < Self.maxAdAge
    }

    func configure(removeAdsOwned: Bool) {
        self.removeAdsOwned = removeAdsOwned
        guard sdkStarted else { return }   // remembered; loads happen in startAfterConsent
        Task {
            await refreshRewardedIfNeeded()
            if !removeAdsOwned, interstitialAd == nil || !isFresh(interstitialLoadedAt) {
                await loadInterstitial()
            }
        }
    }

    /// Loads a rewarded ad unless a fresh one is already waiting.
    func refreshRewardedIfNeeded() async {
        if rewardedAd != nil, isFresh(rewardedLoadedAt) { return }
        await loadRewarded()
    }

    /// v3.1.2 — called once ConsentManager reports `canRequestAds`: starts the SDK, then loads.
    func startAfterConsent(removeAdsOwned: Bool) {
        if !sdkStarted {
            sdkStarted = true
            MobileAds.shared.start(completionHandler: nil)
        }
        configure(removeAdsOwned: removeAdsOwned)
    }

    // MARK: - Rewarded

    func loadRewarded() async {
        guard sdkStarted else { return }   // v3.1.2 — never request before consent
        guard !rewardedLoading else { return }   // v3.4.1 — one request at a time
        rewardedLoading = true
        defer { rewardedLoading = false }
        do {
            let ad = try await RewardedAd.load(with: rewardedUnitId, request: Request())
            let stamp = Date()
            rewardedAd = ad
            rewardedLoadedAt = stamp
            rewardedReady = true
            // Swap it for a new one before AdMob expires it, if it's still unused.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Self.maxAdAge * 1_000_000_000))
                guard let self, self.rewardedLoadedAt == stamp, self.rewardedAd != nil else { return }
                self.rewardedAd = nil
                self.rewardedReady = false
                await self.loadRewarded()
            }
        } catch {
            if !isFresh(rewardedLoadedAt) { rewardedAd = nil; rewardedReady = false }
            print("[AdManager] Rewarded load failed: \(error)")
            // Schedule a background retry. New AdMob accounts often return
            // "no fill" for hours; keep trying so the button comes alive
            // once inventory matches.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await self?.loadRewarded()
            }
        }
    }

    /// Present the rewarded ad. `onReward` is invoked on a successful reward;
    /// `onDismiss` is always invoked once: when the ad closes, or right away
    /// if there was no usable ad. Returns false when nothing was shown.
    @discardableResult
    func showRewarded(from root: UIViewController, onReward: @escaping () -> Void, onDismiss: @escaping () -> Void = {}) -> Bool {
        guard let ad = rewardedAd, isFresh(rewardedLoadedAt) else {
            // None loaded, or it has expired: drop it and fetch a new one.
            rewardedAd = nil
            rewardedReady = false
            onDismiss()
            Task { await loadRewarded() }
            return false
        }
        rewardedAd = nil
        rewardedLoadedAt = nil
        rewardedReady = false
        ad.fullScreenContentDelegate = adWatcher
        watchFullScreenAd(then: onDismiss)
        ad.present(from: root) {
            onReward()
        }
        // Preload the next one while this one plays.
        Task { await loadRewarded() }
        return true
    }

    /// v3.4.1 — a rewarded ad from anywhere outside the Shop (welcome-back,
    /// daily reward), counted in ShopStats under `placement` the way the
    /// Shop's buttons are. Returns false (after `onDismiss`) if no ad was ready.
    @discardableResult
    func watch(placement: String, onReward: @escaping () -> Void, onDismiss: @escaping () -> Void = {}) -> Bool {
        ShopStats.shared.ad(placement)
        guard rewardedReady, let root = UIApplication.shared.topMostViewController() else {
            Task { await loadRewarded() }
            onDismiss()
            return false
        }
        return showRewarded(from: root, onReward: {
            ShopStats.shared.reward(placement)
            onReward()
        }, onDismiss: onDismiss)
    }

    // MARK: - Interstitial

    func loadInterstitial() async {
        guard sdkStarted else { return }   // v3.1.2 — never request before consent
        do {
            let ad = try await InterstitialAd.load(with: interstitialUnitId, request: Request())
            interstitialAd = ad
            interstitialLoadedAt = Date()
            interstitialReady = true
        } catch {
            interstitialReady = false
            print("[AdManager] Interstitial load failed: \(error)")
            // Same retry policy as rewarded — see comment in loadRewarded.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard let self else { return }
                if !self.removeAdsOwned { await self.loadInterstitial() }
            }
        }
    }

    func showInterstitialIfReady(from root: UIViewController) {
        guard !removeAdsOwned else { return }
        if let last = lastInterstitialShownAt, Date().timeIntervalSince(last) < interstitialMinInterval { return }
        guard let ad = interstitialAd, isFresh(interstitialLoadedAt) else {
            interstitialAd = nil
            Task { await loadInterstitial() }
            return
        }
        interstitialAd = nil
        ad.fullScreenContentDelegate = adWatcher
        watchFullScreenAd()
        ad.present(from: root)
        lastInterstitialShownAt = Date()
        interstitialReady = false
        Task { await loadInterstitial() }
    }
}

/// v3.2 — reports when a full-screen ad closes or fails to show. A plain
/// NSObject (not main-actor isolated) so it can be the SDK's delegate; the SDK
/// calls it on the main thread.
final class FullScreenAdWatcher: NSObject, FullScreenContentDelegate {
    var onDismiss: (() -> Void)?

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) { onDismiss?() }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) { onDismiss?() }
}
