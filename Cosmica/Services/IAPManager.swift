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
    ] + tipProductIds

    static let consumableIds: Set<String> = [
        boost2x24hrProductId,
        offline7dayProductId,
        shardsSmallProductId,
        shardsLargeProductId,
        tipSmallProductId, tipMediumProductId, tipLargeProductId,
    ]

    // MARK: - Tip reminder cadence (matches S-Tier Eats)
    private let hasEverTippedKey    = "cosmica.iap.hasEverTipped"
    private let tipNeverAskKey      = "cosmica.tip.neverAsk"
    private let tipLastPromptKey    = "cosmica.tip.lastPromptAt"  // epoch seconds
    private let tipInstallDateKey   = "cosmica.tip.firstSeenAt"   // epoch seconds
    private let graceDays: Double = 14
    private let betweenPromptDays: Double = 60

    // MARK: - State

    var products: [Product] = []
    var removeAdsOwned: Bool = false
    var purchaseInFlight: Bool = false
    /// Briefly true after a successful tip so the UI can show a thank-you beat.
    var didTip: Bool = false
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
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let txn) = result, txn.productID == Self.removeAdsProductId {
                owned = true
                break
            }
        }
        removeAdsOwned = owned
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

    /// Call when the reminder is shown, to reset the 60-day clock.
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
