import Foundation
import Observation
import StoreKit

/// StoreKit 2 wrapper covering all of Cosmica's in-app purchases:
/// - One non-consumable: `removeads` (the original)
/// - Four consumables: boost_2x_24hr, offline_7day, shards_pack_small, shards_pack_large
///
/// Consumable purchases return a success flag via `purchase(productId:)`; the caller
/// (ShopView) is responsible for applying the in-game effect (boost duration, shard
/// grant, etc.) once the receipt verifies.
@MainActor
@Observable
final class IAPManager {
    // MARK: - Product IDs (must match App Store Connect)
    static let removeAdsProductId      = "com.centricfiber.cosmica.removeads"
    static let boost2x24hrProductId    = "com.centricfiber.cosmica.boost_2x_24hr"
    static let offline7dayProductId    = "com.centricfiber.cosmica.offline_7day"
    static let shardsSmallProductId    = "com.centricfiber.cosmica.shards_pack_small"
    static let shardsLargeProductId    = "com.centricfiber.cosmica.shards_pack_large"

    static let allProductIds: [String] = [
        removeAdsProductId,
        boost2x24hrProductId,
        offline7dayProductId,
        shardsSmallProductId,
        shardsLargeProductId,
    ]

    static let consumableIds: Set<String> = [
        boost2x24hrProductId,
        offline7dayProductId,
        shardsSmallProductId,
        shardsLargeProductId,
    ]

    // MARK: - State

    var products: [Product] = []
    var removeAdsOwned: Bool = false
    var purchaseInFlight: Bool = false
    var lastError: String?

    private var updatesTask: Task<Void, Never>?

    func product(for id: String) -> Product? {
        products.first(where: { $0.id == id })
    }

    var removeAdsProduct: Product? { product(for: Self.removeAdsProductId) }

    func displayPrice(for productId: String) -> String? {
        product(for: productId)?.displayPrice
    }

    // MARK: - Lifecycle

    func start() async {
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
    /// For consumables, the caller is responsible for applying the in-game effect before the
    /// transaction is finished — we finish the transaction here on success.
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
}
