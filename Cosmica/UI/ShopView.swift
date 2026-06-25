import SwiftUI

struct ShopView: View {
    @Environment(GameEngine.self) var engine
    @Environment(AdManager.self) var ads
    @Environment(IAPManager.self) var iap
    @Environment(HapticsManager.self) var haptics

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        CurrencyBar().background(.clear)
                        removeAdsCard
                        adBoostCard
                        extendedOfflineCard
                        restoreButton
                        BannerAdSlot()
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Shop")
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var removeAdsCard: some View {
        let owned = iap.removeAdsOwned
        let price = iap.removeAdsProduct?.displayPrice ?? "$2.99"
        return cardBackground {
            HStack(spacing: 14) {
                Image(systemName: owned ? "checkmark.seal.fill" : "rectangle.slash")
                    .font(.title)
                    .foregroundStyle(owned ? .green : .yellow)
                    .frame(width: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remove Ads").font(.headline).foregroundStyle(.white)
                    Text(owned
                         ? "Banner and interstitial ads disabled. Thanks ✨"
                         : "Disable banner & interstitial ads forever. Rewarded ads stay (they give bonuses).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !owned {
                    Button {
                        Task { await iap.purchaseRemoveAds() }
                    } label: {
                        Text(price)
                            .font(.headline)
                            .padding(.vertical, 8).padding(.horizontal, 14)
                            .background(.purple, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }
                    .disabled(iap.purchaseInFlight)
                }
            }
        }
    }

    private var adBoostCard: some View {
        let boosted = engine.state.adBoostMultiplier > 1.0
        return cardBackground {
            HStack(spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
                    .frame(width: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text("2× Earnings for 1 Hour").font(.headline).foregroundStyle(.white)
                    Text(boosted
                         ? "Active — \(formattedRemaining())"
                         : "Watch a short ad. Stacks with everything.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    watchAd {
                        engine.grantAdBoost(duration: 3600)
                        haptics.upgrade()
                    }
                } label: {
                    Text("Watch")
                        .font(.headline)
                        .padding(.vertical, 8).padding(.horizontal, 14)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .disabled(!ads.rewardedReady || boosted)
            }
        }
    }

    private var extendedOfflineCard: some View {
        cardBackground {
            HStack(spacing: 14) {
                Image(systemName: "moon.zzz.fill")
                    .font(.title)
                    .foregroundStyle(.blue)
                    .frame(width: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claim 24h Offline Catch-Up").font(.headline).foregroundStyle(.white)
                    Text("Extends your offline cap from 8h to 24h for this session.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    watchAd {
                        _ = engine.applyOffline(extended: true)
                        haptics.upgrade()
                    }
                } label: {
                    Text("Watch")
                        .font(.headline)
                        .padding(.vertical, 8).padding(.horizontal, 14)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .disabled(!ads.rewardedReady)
            }
        }
    }

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task { await iap.restore() }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.top, 8)
    }

    private func formattedRemaining() -> String {
        guard let exp = engine.state.adBoostExpiresAt else { return "" }
        let remaining = max(0, exp.timeIntervalSinceNow)
        return Formatter.duration(remaining) + " remaining"
    }

    private func watchAd(onReward: @escaping () -> Void) {
        guard let root = UIApplication.shared.topMostViewController() else { return }
        ads.showRewarded(from: root, onReward: onReward)
    }

    @ViewBuilder
    private func cardBackground<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
    }
}

extension UIApplication {
    @MainActor
    func topMostViewController() -> UIViewController? {
        guard let scene = connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              var top = window.rootViewController
        else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
