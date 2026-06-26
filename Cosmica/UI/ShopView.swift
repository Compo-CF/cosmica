import SwiftUI

struct ShopView: View {
    @Environment(GameEngine.self) var engine
    @Environment(AdManager.self) var ads
    @Environment(IAPManager.self) var iap
    @Environment(HapticsManager.self) var haptics

    @State private var adUnavailableAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        CurrencyBar().background(.clear)
                        removeAdsCard
                        sectionHeader("Earnings Boost")
                        boost2xCard
                        sectionHeader("Offline Catch-Up")
                        offlineCatchUpCard
                        sectionHeader("Cosmic Shards")
                        shardsPackCard(productId: IAPManager.shardsSmallProductId, amount: 250, icon: "diamond", color: .cyan, fallbackPrice: "$1.99")
                        shardsPackCard(productId: IAPManager.shardsLargeProductId, amount: 2500, icon: "diamond.fill", color: .teal, fallbackPrice: "$9.99")
                        restoreButton
                        BannerAdSlot()
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Shop")
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Ad not ready yet", isPresented: $adUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("AdMob hasn't loaded the next ad yet — this is common with brand-new ad accounts. Try again in a minute or two; the app retries automatically in the background.")
            }
        }
    }

    // MARK: - Sections

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var removeAdsCard: some View {
        let owned = iap.removeAdsOwned
        let price = iap.displayPrice(for: IAPManager.removeAdsProductId) ?? "$2.99"
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
                        Task {
                            if await iap.purchase(IAPManager.removeAdsProductId) {
                                haptics.purchase()
                            }
                        }
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

    private var boost2xCard: some View {
        let boosted = engine.state.adBoostMultiplier > 1.0
        return cardBackground {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: "bolt.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                        .frame(width: 50)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("2× Earnings Boost").font(.headline).foregroundStyle(.white)
                        Text(boosted
                             ? "Active — \(formattedBoostRemaining())"
                             : "Doubles all Stardust earnings for the duration.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack(spacing: 10) {
                    actionButton(
                        title: ads.rewardedReady ? "Watch Ad" : "Loading…",
                        subtitle: "1 hour",
                        color: .orange,
                        disabled: false
                    ) {
                        watchAd { engine.grantBoost(duration: 3600); haptics.upgrade() }
                    }
                    actionButton(
                        title: iap.displayPrice(for: IAPManager.boost2x24hrProductId) ?? "$1.99",
                        subtitle: "24 hours",
                        color: .purple,
                        disabled: iap.purchaseInFlight
                    ) {
                        Task {
                            if await iap.purchase(IAPManager.boost2x24hrProductId) {
                                engine.grantBoost(duration: 24 * 3600)
                                haptics.purchase()
                            }
                        }
                    }
                }
            }
        }
    }

    private var offlineCatchUpCard: some View {
        cardBackground {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                        .frame(width: 50)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Offline Catch-Up").font(.headline).foregroundStyle(.white)
                        Text("Extend your offline earning cap and claim Stardust now.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack(spacing: 10) {
                    actionButton(
                        title: ads.rewardedReady ? "Watch Ad" : "Loading…",
                        subtitle: "24 hour cap",
                        color: .blue,
                        disabled: false
                    ) {
                        watchAd {
                            _ = engine.applyOfflineCatchUp(cap: 24 * 3600)
                            haptics.upgrade()
                        }
                    }
                    actionButton(
                        title: iap.displayPrice(for: IAPManager.offline7dayProductId) ?? "$2.99",
                        subtitle: "7 day cap",
                        color: .indigo,
                        disabled: iap.purchaseInFlight
                    ) {
                        Task {
                            if await iap.purchase(IAPManager.offline7dayProductId) {
                                _ = engine.applyOfflineCatchUp(cap: 7 * 24 * 3600)
                                haptics.purchase()
                            }
                        }
                    }
                }
            }
        }
    }

    private func shardsPackCard(productId: String, amount: Int, icon: String, color: Color, fallbackPrice: String) -> some View {
        let price = iap.displayPrice(for: productId) ?? fallbackPrice
        return cardBackground {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                    .frame(width: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text("+\(amount) Cosmic Shards ◈").font(.headline).foregroundStyle(.white)
                    Text("Each shard grants +2% permanent earnings forever.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task {
                        if await iap.purchase(productId) {
                            engine.grantShards(amount)
                            haptics.purchase()
                        }
                    }
                } label: {
                    Text(price)
                        .font(.headline)
                        .padding(.vertical, 8).padding(.horizontal, 14)
                        .background(color, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .disabled(iap.purchaseInFlight)
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

    // MARK: - Helpers

    private func actionButton(title: String, subtitle: String, color: Color, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption2).opacity(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(color, in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.white)
            .opacity(disabled ? 0.5 : 1.0)
        }
        .disabled(disabled)
    }

    private func formattedBoostRemaining() -> String {
        guard let exp = engine.state.adBoostExpiresAt else { return "" }
        let remaining = max(0, exp.timeIntervalSinceNow)
        return Formatter.duration(remaining) + " remaining"
    }

    private func watchAd(onReward: @escaping () -> Void) {
        guard ads.rewardedReady else {
            adUnavailableAlert = true
            // Kick off another load attempt so by the time the user dismisses
            // the alert, an ad may be ready.
            Task { await ads.loadRewarded() }
            return
        }
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
