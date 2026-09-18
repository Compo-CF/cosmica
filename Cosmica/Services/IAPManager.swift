import Foundation
import Observation
import StoreKit

/// StoreKit 2 wrapper covering all of Cosmica's in-app purchases:
/// - One non-consumable: `removeads` (the original)
/// - Four consumables: boost_2x_24hr, offline_7day, shards_pack_small, shards_pack_large
/// - Three consumable tips (v1.2): tip.small, tip.medium, tip.large
///
/// Consumable purchases return a success flag via `purchase(productId:)`; the caller
/// (ShopView) is responsible for applying the in-game effect (boost duration, shard
/// grant, etc.) once the receipt verifies.
///
/// The tip reminder algorithm mirrors S-Tier Eats' PurchaseStore: never in the first
/// 14 days after install, at most once every 60 days, never after any tip, and a hard
/// "Don't ask again" opt-out.
@MainActor
@Observable
final class IAPManager {
    // MARK: - Product IDs (must match App Store Connect)
    static let removeAdsProductId      = "com.centricfiber.cosmica.removeads"
    static let boost2x24hrProductId    = "com.centricfiber.cosmica.boost_2x_24hr"
    static let offline7dayProductId    = "com.centricfiber.cosmica.offline_7day"
    static let shardsSmallProductId    = "com.centricfiber.cosmica.shards_pack_small"
    static let shardsLargeProductId    = "com.centricfiber.cosmica.shards_pack_large"

    // v3.0: Automation Core — one-time non-consumable that unlocks the whole
    // automation feature set (auto-buy generators, auto-Big-Bang, auto-collect
    // events, auto-spend Cosmic Tree). Rewarded ad grants a 4-hour trial that
    // sets `GameState.automationTrialExpiresAt` instead of setting this flag.
    static let automationCoreProductId = "com.centricfiber.cosmica.automation_core"

    // v3.0.x: Everything Bundle — one-shot non-consumable that grants both
    // `removeAds` AND `automationCore` entitlements at a discount vs. buying
    // them separately. Apple's ASC has no first-class IAP bundle type, so
    // this is a plain non-consumable whose purchase we treat as granting the
    // two member products' flags below.
    static let everythingBundleProductId = "com.centricfiber.cosmica.everything_bundle"

    // Tip jar (v1.2). All consumables. No in-game effect — pure "buy me a coffee".
    static let tipSmallProductId       = "com.centricfiber.cosmica.tip.small"
    static let tipMediumProductId      = "com.centricfiber.cosmica.tip.medium"
    static let tipLargeProductId       = "com.centricfiber.cosmica.tip.large"

    static let tipProductIds: [String] = [
        tipSmallProductId, tipMediumProductId, tipLargeProductId,
    ]

    static let allProductIds: [String] = [
        removeAdsProductId,
        boost2x24hrProductId,
        offline7dayProductId,
        shardsSmallProductId,
        shardsLargeProductId,
        automationCoreProductId,
        everythingBundleProductId,
    ] + tipProductIds

    static let consumableIds: Set<String> = [
        boost2x24hrProductId,
        offline7dayProductId,
        shardsSmallProductId,
        shardsLargeProductId,
        tipSmallProductId, tipMediumProductId, tipLargeProductId,
    ]

    // MARK: - Tip reminder cadence (tuned in v2.1 for higher opportunity)
    private let hasEverTippedKey    = "cosmica.iap.hasEverTipped"
    private let tipNeverAskKey      = "cosmica.tip.neverAsk"
    private let tipLastPromptKey    = "cosmica.tip.lastPromptAt"  // epoch seconds
    private let tipInstallDateKey   = "cosmica.tip.firstSeenAt"   // epoch seconds
    private let graceDays: Double = 7        // was 14 — bring first ask into week 2 instead of week 3
    private let betweenPromptDays: Double = 45  // was 60 — still respectful, more moments captured

    // MARK: - Boost nudge cadence (v2.1)
    private let boostNudgeLastShownKey = "cosmica.boost.nudge.lastShownAt"
    private let betweenBoostNudgeDays: Double = 7

    // MARK: - State

    var products: [Product] = []
    var removeAdsOwned: Bool = false
    /// v3.0: true once the player owns Automation Core. NOT true during trial —
    /// trial lives on `GameState.automationTrialExpiresAt` and is checked by
    /// `AutomationManager.isActive` together with this flag.
    var automationCoreOwned: Bool = false
    var purchaseInFlight: Bool = false
    /// Briefly true after a successful tip so the UI can show a thank-you beat.
    var didTip: Bool = false
    /// View-layer coordination flag. Non-cold-launch trigger points (first True
    /// Cosmos, first Wonder built) set this to `true`; `RootView` observes and
    /// shows the tip sheet if `tipReminderEligibleForBigMoment` is also true.
    var pendingTipTrigger: Bool = false
    /// Whether the user has ever tipped (persisted). Once true, the reminder never fires again.
    private(set) var hasEverTipped: Bool = false
    var lastError: String?

    private var updatesTask: Task<Void, Never>?

    // MARK: - Lookups

    func product(for id: String) -> Product? {
        products.first(where: { $0.id == id })
    }

    var removeAdsProduct: Product? { product(for: Self.removeAdsProductId) }

    /// The three tip products, sorted small → large by price.
    var tipProducts: [Product] {
        products
            .filter { Self.tipProductIds.contains($0.id) }
            .sorted { $0.price < $1.price }
    }

    func displayPrice(for productId: String) -> String? {
        product(for: productId)?.displayPrice
    }

    // MARK: - Lifecycle

    func start() async {
        // Stamp first-seen exactly once so the grace-period clock has a baseline.
        if UserDefaults.standard.object(forKey: tipInstallDateKey) == nil {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: tipInstallDateKey)
        }
        hasEverTipped = UserDefaults.standard.bool(forKey: hasEverTippedKey)
        updatesTask?.cancel()
        updatesTask = listenForTransactions()
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.allProductIds)
        } catch {
            lastError = "Couldn't load products: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchases

    /// Purchases the product with the given ID. Returns `true` on a verified successful purchase.
    @discardableResult
    func purchase(_ productId: String) async -> Bool {
        guard let product = product(for: productId) else {
            lastError = "Product unavailable: \(productId)"
            return false
        }
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let txn) = verification else {
                    lastError = "Purchase couldn't be verified."
                    return false
                }
                if productId == Self.removeAdsProductId {
                    removeAdsOwned = true
                }
                if productId == Self.automationCoreProductId {
                    automationCoreOwned = true
                }
                if productId == Self.everythingBundleProductId {
                    // v3.0.x — bundle grants both member entitlements.
                    removeAdsOwned = true
                    automationCoreOwned = true
                }
                if Self.tipProductIds.contains(productId) {
                    markTipped()
                }
                await txn.finish()
                return true
            case .userCancelled:
                return false
            case .pending:
                lastError = "Purchase pending — check back after it clears."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    /// Convenience for the TipReminderView — same purchase flow, but flips `didTip`
    /// so a caller can show a small thank-you beat before dismissing.
    @discardableResult
    func purchaseTip(_ product: Product) async -> Bool {
        await purchase(product.id)
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
        }
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        // v3.0: two non-consumables (Remove Ads + Automation Core). v3.0.x adds
        // the Everything Bundle, whose ownership implies BOTH member flags.
        // Iterate the full entitlement list so a bundle transaction or
        // individual purchases both settle to the right flags in one pass.
        var removeAds = false
        var automation = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let txn) = result else { continue }
            switch txn.productID {
            case Self.removeAdsProductId:        removeAds = true
            case Self.automationCoreProductId:   automation = true
            case Self.everythingBundleProductId: removeAds = true; automation = true
            default: break
            }
        }
        removeAdsOwned = removeAds
        automationCoreOwned = automation
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard let self else { break }
                if case .verified(let txn) = update {
                    await self.refreshEntitlements()
                    await txn.finish()
                }
            }
        }
    }

    // MARK: - Tip reminder gating (mirrors S-Tier Eats PurchaseStore)

    /// Whether it's OK to surface the gentle tip reminder on this launch.
    /// False if: opted out, already tipped, tip products not loaded, purchase in
    /// flight, still in the 2-week grace after install, or fewer than 60 days
    /// since the last prompt.
    var tipReminderEligible: Bool {
        let d = UserDefaults.standard
        guard !d.bool(forKey: tipNeverAskKey),
              !hasEverTipped,
              !tipProducts.isEmpty,
              !purchaseInFlight
        else { return false }
        let now = Date().timeIntervalSince1970
        let firstSeen = d.double(forKey: tipInstallDateKey)
        guard firstSeen > 0, now - firstSeen >= graceDays * 86400 else { return false }
        let last = d.double(forKey: tipLastPromptKey)
        return last == 0 ? true : (now - last >= betweenPromptDays * 86400)
    }

    /// Same gates as `tipReminderEligible` EXCEPT the between-prompt cooldown.
    /// Use ONLY from one-shot big-moment triggers (first True Cosmos, first Wonder
    /// build) where the emotional beat justifies bypassing cadence. Still honors
    /// opt-out, already-tipped, grace period, product-load — all the real gates.
    var tipReminderEligibleForBigMoment: Bool {
        let d = UserDefaults.standard
        guard !d.bool(forKey: tipNeverAskKey),
              !hasEverTipped,
              !tipProducts.isEmpty,
              !purchaseInFlight
        else { return false }
        let now = Date().timeIntervalSince1970
        let firstSeen = d.double(forKey: tipInstallDateKey)
        return firstSeen > 0 && now - firstSeen >= graceDays * 86400
    }

    /// Boost-nudge sheet is eligible when: player is monetizable (no Remove Ads yet
    /// — those users already engaged), the boost product loaded, and it's been at
    /// least `betweenBoostNudgeDays` since the last showing.
    var boostNudgeEligible: Bool {
        guard !removeAdsOwned else { return false }
        guard product(for: Self.boost2x24hrProductId) != nil else { return false }
        let now = Date().timeIntervalSince1970
        let last = UserDefaults.standard.double(forKey: boostNudgeLastShownKey)
        return last == 0 ? true : (now - last >= betweenBoostNudgeDays * 86400)
    }

    /// Call when the boost nudge sheet is presented, to reset the 7-day clock.
    func recordBoostNudgeShown() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: boostNudgeLastShownKey)
    }

    /// Call when the reminder is shown, to reset the between-prompt clock.
    func recordTipPromptShown() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: tipLastPromptKey)
    }

    /// "Don't ask again" — permanently silences the reminder.
    func stopTipReminders() {
        UserDefaults.standard.set(true, forKey: tipNeverAskKey)
    }

    private func markTipped() {
        didTip = true
        hasEverTipped = true
        UserDefaults.standard.set(true, forKey: hasEverTippedKey)
    }
}
