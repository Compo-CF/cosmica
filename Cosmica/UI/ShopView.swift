import SwiftUI

struct ShopView: View {
    @Environment(GameEngine.self) var engine
    @Environment(AdManager.self) var ads
    @Environment(IAPManager.self) var iap
    @Environment(HapticsManager.self) var haptics
    @Environment(AutomationManager.self) var automation
    @Environment(ReviewPrompter.self) var reviewPrompter

    @State private var adUnavailableAlert = false
    @State private var purchaseErrorAlert = false
    @State private var purchaseErrorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        CurrencyBar().background(.clear)
                        if !iap.removeAdsOwned && !iap.automationCoreOwned {
                            bundleCard
                        }
                        removeAdsCard
                        // v3.1 — only shown once the App Store has loaded at
                        // least one Time Warp product (never an unbuyable price).
                        if iap.product(for: IAPManager.timeWarp8hProductId) != nil
                            || iap.product(for: IAPManager.timeWarp24hProductId) != nil {
                            sectionHeader("Time Warp")
                            timeWarpCard
                        }
                        sectionHeader("Earnings Boost")
                        boost2xCard
                        sectionHeader("Offline Catch-Up")
                        offlineCatchUpCard
                        sectionHeader("Cosmic Shards")
                        // v3.1 — packs scale with the player: the larger of the
                        // original fixed amount and 1× / 10× the last Big Bang.
                        shardsPackCard(productId: IAPManager.shardsSmallProductId, base: 250, multiple: 1, bigBangs: "1 Big Bang", icon: "diamond", color: .cyan, fallbackPrice: "$1.99")
                        shardsPackCard(productId: IAPManager.shardsLargeProductId, base: 2500, multiple: 10, bigBangs: "10 Big Bangs", icon: "diamond.fill", color: .teal, fallbackPrice: "$9.99")
                        sectionHeader("Automation")
                        automationCard
                        if iap.supporterOwned || iap.product(for: IAPManager.supporterProductId) != nil {
                            sectionHeader("Support the Developer")
                            supporterCard
                        }
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
            .alert("Purchase Unavailable", isPresented: $purchaseErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseErrorMessage.isEmpty
                     ? "This item isn't available right now. The App Store may still be preparing the products — try again in a few minutes."
                     : purchaseErrorMessage)
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

    // v3.0.x — Everything Bundle. Hidden once the player owns either component
    // so we never charge them for something they already have. On purchase, the
    // IAPManager grants both `removeAdsOwned` and `automationCoreOwned`, which
    // makes this card disappear on the next render.
    private var bundleCard: some View {
        let price = iap.displayPrice(for: IAPManager.everythingBundleProductId) ?? "$4.99"
        return cardBackground {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text("BEST VALUE")
                        .font(.caption2.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.yellow, in: Capsule())
                    Text("Save vs. buying separately")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                HStack(spacing: 14) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.title)
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .yellow],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 50)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Everything Bundle")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Remove Ads + Automation Core, forever. One tap, one purchase.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Button {
                    Task {
                        await attemptPurchase(IAPManager.everythingBundleProductId) {
                            haptics.purchase()
                        }
                    }
                } label: {
                    Text(price)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(
                            LinearGradient(colors: [.orange, .yellow],
                                           startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .foregroundStyle(.black)
                }
                .disabled(iap.purchaseInFlight)
            }
        }
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
                        Task { await attemptPurchase(IAPManager.removeAdsProductId) { haptics.purchase() } }
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
                        subtitle: engine.boostLabel(3600),
                        color: .orange,
                        disabled: false
                    ) {
                        watchAd { engine.grantBoost(duration: 3600); haptics.upgrade() }
                    }
                    actionButton(
                        title: iap.displayPrice(for: IAPManager.boost2x24hrProductId) ?? "$1.99",
                        subtitle: engine.boostLabel(24 * 3600),
                        color: .purple,
                        disabled: iap.purchaseInFlight
                    ) {
                        Task {
                            await attemptPurchase(IAPManager.boost2x24hrProductId) {
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
                            await attemptPurchase(IAPManager.offline7dayProductId) {
                                _ = engine.applyOfflineCatchUp(cap: 7 * 24 * 3600)
                                haptics.purchase()
                            }
                        }
                    }
                }
            }
        }
    }

    private func shardsPackCard(productId: String, base: Double, multiple: Double, bigBangs: String,
                                icon: String, color: Color, fallbackPrice: String) -> some View {
        let price = iap.displayPrice(for: productId) ?? fallbackPrice
        let amount = engine.shardPackAmount(base: base, multiple: multiple)
        return cardBackground {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                    .frame(width: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text("+\(Formatter.short(amount)) Cosmic Shards ◈").font(.headline).foregroundStyle(.white)
                    Text("Worth \(bigBangs) at your current progress (at least \(Formatter.short(base))). Each shard is +2% earnings.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task {
                        await attemptPurchase(productId) {
                            // Sized at the moment of purchase, so it matches the card.
                            engine.grantShards(engine.shardPackAmount(base: base, multiple: multiple))
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

    // v3.1: Time Warp. Shows exactly what each warp would add right now (it's
    // N hours at the current full rate), so the price is easy to judge. A
    // button only appears for a product the App Store has actually loaded.
    private var timeWarpCard: some View {
        cardBackground {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.title)
                        .foregroundStyle(.mint)
                        .frame(width: 50)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Time Warp").font(.headline).foregroundStyle(.white)
                        Text("Get hours of production instantly, at your full rate. Grows with you.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack(spacing: 10) {
                    timeWarpButton(IAPManager.timeWarp8hProductId, hours: 8, color: .mint)
                    timeWarpButton(IAPManager.timeWarp24hProductId, hours: 24, color: .teal)
                }
            }
        }
    }

    @ViewBuilder
    private func timeWarpButton(_ productId: String, hours: Double, color: Color) -> some View {
        if let price = iap.displayPrice(for: productId) {
            // Never sell a warp worth nothing: with no production yet (a fresh
            // game) the button waits until the first generator is running.
            let amount = engine.timeWarpAmount(hours: hours)
            actionButton(
                title: price,
                subtitle: amount > 0 ? "\(Int(hours))h · +\(Formatter.short(amount)) ✦" : "Buy a generator first",
                color: color,
                disabled: iap.purchaseInFlight || amount <= 0
            ) {
                Task {
                    await attemptPurchase(productId) {
                        engine.applyTimeWarp(hours: hours)
                        haptics.purchase()
                    }
                }
            }
        }
    }

    // v3.1: Supporter Pack. A non-consumable thank-you (golden orb + badge);
    // the tip jar sold nothing in 60 days, players buy things rather than donate.
    private var supporterCard: some View {
        let owned = iap.supporterOwned
        return cardBackground {
            HStack(spacing: 14) {
                Image(systemName: owned ? "star.circle.fill" : "star.circle")
                    .font(.title)
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    .frame(width: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Supporter Pack").font(.headline).foregroundStyle(.white)
                    Text(owned
                         ? "Thank you! Your golden orb and Supporter badge are on (switch the orb in Settings)."
                         : "Cosmica is made by one person. Support it and get a golden tap orb and a Supporter badge.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !owned, let price = iap.displayPrice(for: IAPManager.supporterProductId) {
                    Button {
                        Task { await attemptPurchase(IAPManager.supporterProductId) { haptics.upgrade() } }
                    } label: {
                        Text(price)
                            .font(.headline)
                            .padding(.vertical, 8).padding(.horizontal, 14)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.black)
                    }
                    .disabled(iap.purchaseInFlight)
                }
            }
        }
    }

    // v3.0: Automation Core card. Buy path grants a one-time non-consumable that
    // unlocks the whole automation feature set. Watch-Ad path grants a 4-hour
    // trial. Both go through the same paths used by every other card in this file.
    private var automationCard: some View {
        let owned = iap.automationCoreOwned
        let trialing = automation.trialActive
        let price = iap.displayPrice(for: IAPManager.automationCoreProductId) ?? "$2.99"
        return cardBackground {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: owned ? "checkmark.seal.fill" : "sparkles.rectangle.stack.fill")
                        .font(.title)
                        .foregroundStyle(owned ? .green : .yellow)
                        .frame(width: 50)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automation Core").font(.headline).foregroundStyle(.white)
                        Text(owned
                             ? "Automation unlocked. Tap the gear on a generator to auto-buy it; auto-Big-Bang is on the Big Bang tab."
                             : (trialing
                                ? "Trial · \(Formatter.duration(automation.trialRemaining)) left. Tap the gear on a generator to auto-buy it."
                                : "Auto-buy generators and auto-Big-Bang. Works on your first generators right away. Try 4 hours free."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                if !owned {
                    HStack(spacing: 10) {
                        actionButton(
                            title: ads.rewardedReady ? "Watch Ad" : "Loading…",
                            subtitle: "4 hours",
                            color: .orange,
                            disabled: false
                        ) {
                            watchAd {
                                automation.grantTrial(hours: 4)
                                haptics.upgrade()
                            }
                        }
                        actionButton(
                            title: price,
                            subtitle: "Forever",
                            color: .purple,
                            disabled: iap.purchaseInFlight
                        ) {
                            Task {
                                await attemptPurchase(IAPManager.automationCoreProductId) {
                                    haptics.purchase()
                                }
                            }
                        }
                    }
                }
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

    /// Attempts an IAP purchase and surfaces failures with a user-visible alert.
    /// Previously, when the product wasn't loaded StoreKit returned nil and nothing
    /// happened — that read as an "unresponsive" button to App Review and triggered
    /// the 2.1(b) App Completeness rejection.
    @MainActor
    private func attemptPurchase(_ productId: String, onSuccess: @escaping () -> Void) async {
        let ok = await iap.purchase(productId)
        if ok {
            onSuccess()
            // v3.0.5 — a buyer who just got what they paid for is the happiest
            // player we have. Wait for the StoreKit sheet to finish closing.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                reviewPrompter.maybePrompt(reason: "purchase_\(productId)")
            }
            return
        }
        // Purchase didn't complete. If it was a user cancel there's no lastError set,
        // and showing an alert would be annoying — only show it when we have an actual
        // error message to display.
        if let msg = iap.lastError, !msg.isEmpty {
            purchaseErrorMessage = msg
            purchaseErrorAlert = true
            iap.lastError = nil
        } else if iap.product(for: productId) == nil {
            // Product just isn't loaded yet — surface this so the button doesn't feel dead.
            purchaseErrorMessage = "The App Store hasn't loaded this product yet. It may still be preparing after a recent purchase configuration change — try again in a moment."
            purchaseErrorAlert = true
        }
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
