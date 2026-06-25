import Foundation
import Observation
import StoreKit

/// StoreKit 2 wrapper for the single non-consumable Remove Ads IAP.
@MainActor
@Observable
final class IAPManager {
    static let removeAdsProductId = "com.centricfiber.cosmica.removeads"

    var products: [Product] = []
    var removeAdsOwned: Bool = false
    var purchaseInFlight: Bool = false
    var lastError: String?

    private var updatesTask: Task<Void, Never>?

    var removeAdsProduct: Product? {
        products.first(where: { $0.id == Self.removeAdsProductId })
    }

    func start() async {
        updatesTask?.cancel()
        updatesTask = listenForTransactions()
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.removeAdsProductId])
        } catch {
            lastError = "Couldn't load products: \(error.localizedDescription)"
        }
    }

    func purchaseRemoveAds() async {
        guard let product = removeAdsProduct else {
            lastError = "Remove Ads product not available."
            return
        }
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let txn) = verification {
                    removeAdsOwned = true
                    await txn.finish()
                } else {
                    lastError = "Purchase couldn't be verified."
                }
            case .userCancelled:
                break
            case .pending:
                lastError = "Purchase pending — check back after it clears."
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
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
                guard let self else { continue }
                if case .verified(let txn) = update {
                    await self.refreshEntitlements()
                    await txn.finish()
                }
            }
        }
    }

    deinit { updatesTask?.cancel() }
}
