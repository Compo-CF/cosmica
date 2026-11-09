import SwiftUI
import StoreKit

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
    /// v3.4 — cards already counted as seen during this visit to the Shop.
    @State private var seenThisVisit: Set<String> = []

    private var stats: ShopStats { ShopStats.shared }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    // v3.4 — Lazy, so a card's onAppear means it actually scrolled
                    // on screen (ShopStats counts it as seen).
                    LazyVStack(spacing: 16) {
                        CurrencyBar().background(.clear)
                        switch iap.premiumOffer {
                        case .ultimate, .deluxe: premiumCard
                        case .completeSet:       completeSetCard
                        case .none:              EmptyView()
                        }
                        if !iap.removeAdsOwned && !iap.automationCoreOwned {
                            bundleCard.seen("everything_bundle", in: self)
                        }
                        if IAPManager.showsStandaloneRemoveAds(
                            iap.entitlements,
                            removeAdsLoaded: iap.product(for: IAPManager.removeAdsProductId) != nil) {
                            removeAdsCard.seen("removeads", in: self)
                        }
                        sectionHeader("Time Warp")
                        timeWarpCard.seen("timewarp", in: self)
                        sectionHeader("Earnings Boost")
                        // v3.3 — permanent ×2; only shown once StoreKit has it (or it's owned).
                        if iap.doublerOwned || iap.product(for: IAPManager.stardustDoublerProductId) != nil {
                            doublerCard.seen("stardust_doubler", in: self)
                        }
                        boost2xCard.seen("boost", in: self)
                        sectionHeader("Offline Catch-Up")
                        offlineCatchUpCard.seen("offline", in: self)
                        sectionHeader("Cosmic Shards")
                        shardsPackCard(productId: IAPManager.shardsSmallProductId,
                                       pack: GameEngine.smallShardPack, icon: "diamond", color: .cyan)
                            .seen("shards_pack_small", in: self)
                        shardsPackCard(productId: IAPManager.shardsLargeProductId,
                                       pack: GameEngine.largeShardPack, icon: "diamond.fill", color: .teal)
                            .seen("shards_pack_large", in: self)
                        sectionHeader("Automation")
                        automationCard.seen("automation_core", in: self)
                        if iap.supporterOwned || iap.product(for: IAPManager.supporterProductId) != nil {
                            sectionHeader("Support the Developer")
                            supporterCard.seen("supporter", in: self)
                        }
                        restoreButton
                        BannerAdSlot()
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Shop")
            // 3.3.1 — if the launch-time product load failed (offline, slow
            // network), try again whenever the Shop opens.
            .task {
                if iap.products.isEmpty { await iap.loadProducts() }
            }
            .onAppear {
                seenThisVisit = []
                stats.open()
            }
            .onDisappear {
                Task { await ShopStats.shared.flush() }
            }
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

    /// Count a card as seen once per visit.
    @MainActor
    fileprivate func markSeen(_ card: String) {
        guard !seenThisVisit.contains(card) else { return }
        seenThisVisit.insert(card)
        stats.view(card)
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

    // v3.4 — the premium tier. Ultimate for players who own none of its parts;
    // Deluxe Upgrade for Everything Bundle owners (Apple has no upgrade
    // pricing). `IAPManager.premiumOffer` never offers anything already owned.
    // Shown only once StoreKit has loaded the product: never a made-up price.
    @ViewBuilder
    private var premiumCard: some View {
        let ultimate = iap.premiumOffer == .ultimate
        let productId = ultimate ? IAPManager.ultimateBundleProductId : IAPManager.deluxeUpgradeProductId
        if let price = iap.displayPrice(for: productId) {
            let parts = ultimate
                ? [IAPManager.removeAdsProductId, IAPManager.automationCoreProductId,
                   IAPManager.stardustDoublerProductId, IAPManager.supporterProductId]
                : [IAPManager.stardustDoublerProductId, IAPManager.supporterProductId]
            let bullets: [(icon: String, text: String)] = (ultimate ? [
                ("rectangle.slash", "No banner or interstitial ads"),
                ("gearshape.2.fill", "Automation Core: auto-buy and auto-Big-Bang"),
            ] : []) + [
                ("infinity.circle.fill", "Stardust Doubler: every Stardust ×2, forever"),
                ("star.circle.fill", "Supporter Pack: golden orb and Supporter badge"),
                ("circle.circle.fill", "The Singularity orb, only in this pack"),
            ]
            cardBackground {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Text(ultimate ? "EVERYTHING" : "UPGRADE YOUR BUNDLE")
                            .font(.caption2.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(LinearGradient(colors: [.pink, .orange], startPoint: .leading, endPoint: .trailing),
                                        in: Capsule())
                        if let worth = separatePrice(parts) {
                            Text("\(worth) if bought separately")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    Text(ultimate ? "Ultimate Bundle" : "Deluxe Upgrade")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(bullets.indices, id: \.self) { i in
                            Label(bullets[i].text, systemImage: bullets[i].icon)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    Button {
                        Task { await attemptPurchase(productId) { haptics.purchase() } }
                    } label: {
                        Text(price)
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(LinearGradient(colors: [.pink, .orange], startPoint: .leading, endPoint: .trailing),
                                        in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.black)
                    }
                    .disabled(iap.purchaseInFlight)
                }
            }
            .seen(ShopStats.key(productId), in: self)
        }
    }

    // v3.4.2 — Complete Your Set. For players who bought some permanent pieces
    // one at a time and so fit neither bundle: lists only what they're missing,
    // each at its own App Store price (Apple has no upgrade pricing, so nothing
    // here ever charges for something they own). Rows wait for StoreKit's
    // price; the card hides if none has loaded.
    @ViewBuilder
    private var completeSetCard: some View {
        let e = iap.entitlements
        let missing = IAPManager.missingSetPieces(e).filter { iap.product(for: $0) != nil }
        if !missing.isEmpty {
            let owned = IAPManager.setPieceIds.count - IAPManager.missingSetPieces(e).count
            cardBackground {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Text("COMPLETE YOUR SET")
                            .font(.caption2.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(LinearGradient(colors: [.pink, .orange], startPoint: .leading, endPoint: .trailing),
                                        in: Capsule())
                        Text("You own \(owned) of \(IAPManager.setPieceIds.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    ForEach(missing, id: \.self) { id in
                        setPieceRow(id)
                    }
                    if let key = IAPManager.deluxeUnlockedBy(e),
                       let deluxe = iap.displayPrice(for: IAPManager.deluxeUpgradeProductId) {
                        Label("Own \(setPieceInfo(key).name) too and the Deluxe Upgrade opens: Stardust Doubler, Supporter Pack and the Singularity orb for \(deluxe).",
                              systemImage: "circle.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .seen("complete_set", in: self)
        }
    }

    private func setPieceInfo(_ id: String) -> (name: String, blurb: String, icon: String, color: Color) {
        switch id {
        case IAPManager.removeAdsProductId:
            return ("Remove Ads", "No banner or interstitial ads", "rectangle.slash", .yellow)
        case IAPManager.automationCoreProductId:
            return ("Automation Core", "Auto-buy and auto-Big-Bang", "gearshape.2.fill", .green)
        case IAPManager.stardustDoublerProductId:
            return ("Stardust Doubler", "Every Stardust ×2, forever", "infinity.circle.fill", .orange)
        default:
            return ("Supporter Pack", "Golden orb and Supporter badge", "star.circle.fill", .yellow)
        }
    }

    private func setPieceRow(_ id: String) -> some View {
        let info = setPieceInfo(id)
        return HStack(spacing: 12) {
            Image(systemName: info.icon)
                .font(.title3)
                .foregroundStyle(info.color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name).font(.subheadline.bold()).foregroundStyle(.white)
                Text(info.blurb).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await attemptPurchase(id) { haptics.purchase() } }
            } label: {
                Text(iap.priceLabel(for: id))
                    .font(.subheadline.bold())
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(LinearGradient(colors: [.pink, .orange], startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.black)
            }
            .disabled(iap.purchaseInFlight)
        }
    }

    /// The App Store prices of `productIds` added up, in the store's own
    /// currency; nil unless every one has loaded.
    private func separatePrice(_ productIds: [String]) -> String? {
        let products = productIds.compactMap { iap.product(for: $0) }
        guard products.count == productIds.count, let first = products.first else { return nil }
        let total = products.reduce(Decimal(0)) { $0 + $1.price }
        return total.formatted(first.priceFormatStyle)
    }

    // v3.0.x — Everything Bundle. Hidden once the player owns either component
    // so we never charge them for something they already have. On purchase, the
    // IAPManager grants both `removeAdsOwned` and `automationCoreOwned`, which
    // makes this card disappear on the next render.
    private var bundleCard: some View {
        let price = iap.priceLabel(for: IAPManager.everythingBundleProductId)
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
        let price = iap.priceLabel(for: IAPManager.removeAdsProductId)
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

    /// v3.3 — Stardust Doubler: ×2 earnings forever. Shows what it's worth to
    /// this player right now (their current rate again, per second), so the
    /// price is judged against something concrete.
    private var doublerCard: some View {
        let owned = iap.doublerOwned
        let rate = engine.state.stardustPerSecond
        return cardBackground {
            HStack(spacing: 14) {
                Image(systemName: owned ? "checkmark.seal.fill" : "infinity.circle.fill")
                    .font(.title)
                    .foregroundStyle(owned ? .green : .orange)
                    .frame(width: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stardust Doubler").font(.headline).foregroundStyle(.white)
                    Text(owned
                         ? "Owned: every Stardust you earn is doubled, forever ✨"
                         : "All Stardust earnings ×2, forever. Stacks with boosts and survives every Big Bang and True Cosmos.")
                        .font(.caption).foregroundStyle(.secondary)
                    if !owned && rate > 0 {
                        Text("Right now that's +\(Formatter.short(rate)) ✦/s")
                            .font(.caption.bold()).foregroundStyle(.orange)
                    }
                }
                Spacer()
                if !owned, let price = iap.displayPrice(for: IAPManager.stardustDoublerProductId) {
                    Button {
                        Task { await attemptPurchase(IAPManager.stardustDoublerProductId) { haptics.purchase() } }
                    } label: {
                        Text(price)
                            .font(.headline)
                            .padding(.vertical, 8).padding(.horizontal, 14)
                            .background(.orange, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.black)
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
                        watchAd(placement: "boost") { engine.grantBoost(duration: 3600); haptics.upgrade() }
                    }
                    actionButton(
                        title: iap.priceLabel(for: IAPManager.boost2x24hrProductId),
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

    // v3.4.1 — Catch-Up pays the part of your last absence the base cap cut
    // off (it used to measure from the last save and pay for seconds). Both
    // buttons say what they'd add, and neither sells anything worth nothing.
    private var offlineCatchUpCard: some View {
        let adAmount = engine.offlineCatchUpAmount(cap: engine.adCatchUpCap)
        let iapAmount = engine.offlineCatchUpAmount(cap: engine.iapCatchUpCap)
        return cardBackground {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                        .frame(width: 50)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Offline Catch-Up").font(.headline).foregroundStyle(.white)
                        Text(iapAmount > 0
                             ? "Your last time away was \(Formatter.duration(engine.state.lastAwaySeconds)); your cap counted \(Formatter.duration(engine.state.lastAwayPaidSeconds)). Claim the rest."
                             : "When you're away longer than your offline cap, claim the time it missed here.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack(spacing: 10) {
                    actionButton(
                        title: adAmount <= 0 ? "Nothing missed" : (ads.rewardedReady ? "Watch Ad" : "Loading…"),
                        subtitle: adAmount > 0 ? "Up to 24h · +\(Formatter.short(adAmount)) ✦" : "24 hour cap",
                        color: .blue,
                        disabled: adAmount <= 0
                    ) {
                        watchAd(placement: "offline") {
                            _ = engine.applyOfflineCatchUp(cap: engine.adCatchUpCap)
                            haptics.upgrade()
                        }
                    }
                    actionButton(
                        title: iapAmount <= 0 ? "Nothing missed" : iap.priceLabel(for: IAPManager.offline7dayProductId),
                        subtitle: iapAmount > 0 ? "Up to 7 days · +\(Formatter.short(iapAmount)) ✦" : "7 day cap",
                        color: .indigo,
                        disabled: iap.purchaseInFlight || iapAmount <= 0
                    ) {
                        Task {
                            await attemptPurchase(IAPManager.offline7dayProductId) {
                                _ = engine.applyOfflineCatchUp(cap: engine.iapCatchUpCap)
                                haptics.purchase()
                            }
                        }
                    }
                }
            }
        }
    }

    // v3.4 — packs are sized in Big Bangs (3 and 30) and say what they'd let
    // the player buy next, not just how many shards they are.
    private func shardsPackCard(productId: String, pack: (base: Double, bigBangs: Double),
                                icon: String, color: Color) -> some View {
        let price = iap.priceLabel(for: productId)
        let amount = engine.shardPackAmount(base: pack.base, multiple: pack.bigBangs)
        let target = engine.shardPackTarget(amount: amount)
        return cardBackground {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                    .frame(width: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text("+\(Formatter.short(amount)) Cosmic Shards ◈").font(.headline).foregroundStyle(.white)
                    Text("Worth \(Int(pack.bigBangs)) Big Bangs at your progress.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let target {
                        Text("Enough for \(target.name) (\(Formatter.short(target.cost)) ◈)")
                            .font(.caption.bold()).foregroundStyle(color)
                    } else {
                        Text("Unspent shards add +2% earnings each.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    Task {
                        await attemptPurchase(productId) {
                            // Sized at the moment of purchase, so it matches the card.
                            engine.grantShards(engine.shardPackAmount(base: pack.base, multiple: pack.bigBangs))
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
    // buy button only appears for a product the App Store has actually loaded.
    // v3.4: plus a free 30-minute warp once a day for watching an ad.
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
                freeWarpButton
                if iap.product(for: IAPManager.timeWarp8hProductId) != nil
                    || iap.product(for: IAPManager.timeWarp24hProductId) != nil {
                    HStack(spacing: 10) {
                        timeWarpButton(IAPManager.timeWarp8hProductId, hours: 8, color: .mint)
                        timeWarpButton(IAPManager.timeWarp24hProductId, hours: 24, color: .teal)
                    }
                }
            }
        }
    }

    private var freeWarpButton: some View {
        let available = engine.freeWarpAvailable()
        let amount = engine.timeWarpAmount(hours: GameEngine.freeWarpHours)
        let title = !available ? "Claimed today" : (ads.rewardedReady ? "Watch Ad · Free" : "Loading…")
        let subtitle = !available ? "Your free warp is back tomorrow"
            : (amount > 0 ? "30 min · +\(Formatter.short(amount)) ✦, once a day" : "Buy a generator first")
        return actionButton(title: title, subtitle: subtitle, color: .green,
                            disabled: !available || amount <= 0) {
            watchAd(placement: "free_warp") {
                if engine.claimFreeWarp() > 0 { haptics.upgrade() }
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
        let price = iap.priceLabel(for: IAPManager.automationCoreProductId)
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
                            watchAd(placement: "automation") {
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
        stats.tap(productId)
        // 3.3.1 — a button still showing "Loading…" retries the App Store load,
        // then buys if the product arrived, rather than failing outright.
        if iap.product(for: productId) == nil {
            await iap.loadProducts()
            guard iap.product(for: productId) != nil else {
                iap.lastError = nil
                purchaseErrorMessage = "Couldn't reach the App Store for this item. Check your connection and try again in a moment."
                purchaseErrorAlert = true
                return
            }
        }
        let ok = await iap.purchase(productId)
        if ok {
            stats.buy(productId)
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

    private func watchAd(placement: String, onReward: @escaping () -> Void) {
        stats.ad(placement)
        guard ads.rewardedReady else {
            adUnavailableAlert = true
            // Kick off another load attempt so by the time the user dismisses
            // the alert, an ad may be ready.
            Task { await ads.loadRewarded() }
            return
        }
        guard let root = UIApplication.shared.topMostViewController() else { return }
        let shown = ads.showRewarded(from: root, onReward: {
            ShopStats.shared.reward(placement)
            onReward()
        })
        if !shown { adUnavailableAlert = true }   // v3.4.1 — the loaded ad had expired
    }

    @ViewBuilder
    private func cardBackground<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
    }
}

private extension View {
    /// v3.4 — counts the card as seen (once per Shop visit) when it scrolls on screen.
    @MainActor
    func seen(_ card: String, in shop: ShopView) -> some View {
        onAppear { shop.markSeen(card) }
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
