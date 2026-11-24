import Foundation

/// v4.0.6 — Black Friday 2026. The Ultimate Bundle ($12.99 -> $7.99) and the Deluxe Upgrade
/// ($9.99 -> $5.99) are on sale from 27 Nov to Cyber Monday, 1 Dec. The price change itself is
/// scheduled in App Store Connect (manual prices with start and end dates), so StoreKit's price
/// IS the sale price; this file only decides when the app says so.
///
/// It never claims a sale the App Store isn't charging: when the app remembers the price from
/// before the sale, today's price must be lower than it.
enum BlackFridaySale {
    /// 27 Nov 2026 08:00 UTC (midnight Pacific) -> 2 Dec 2026 08:00 UTC (end of Cyber Monday, Pacific).
    static let start = Date(timeIntervalSince1970: 1_795_766_400)
    static let end   = Date(timeIntervalSince1970: 1_796_198_400)

    static func isOpen(_ now: Date) -> Bool { now >= start && now < end }

    /// The product on sale for this player: Ultimate for players who own none of its parts,
    /// Deluxe for Everything Bundle owners. Nothing for anyone else.
    @MainActor
    static func productId(for offer: IAPManager.PremiumOffer) -> String? {
        switch offer {
        case .ultimate: return IAPManager.ultimateBundleProductId
        case .deluxe:   return IAPManager.deluxeUpgradeProductId
        case .completeSet, .none: return nil
        }
    }

    /// Show the sale only inside the window, once StoreKit has a price, and (if the pre-sale
    /// price is remembered) only while today's price is below it.
    static func onSale(now: Date, price: Decimal?, regular: Decimal?) -> Bool {
        guard isOpen(now), let price else { return false }
        if let regular { return price < regular }
        return true
    }

    // MARK: - Pre-sale price memory

    static func regularKey(_ productId: String) -> String { "bf2026.regular.\(productId)" }

    /// Remember a product's price, but only before the sale starts, so the sale price is never
    /// learned as the "regular" one.
    static func remember(_ productId: String, price: Decimal, label: String, now: Date,
                         defaults: UserDefaults = .standard) {
        guard now < start else { return }
        defaults.set(NSDecimalNumber(decimal: price).stringValue, forKey: regularKey(productId))
        defaults.set(label, forKey: regularKey(productId) + ".label")
    }

    static func regular(_ productId: String, defaults: UserDefaults = .standard) -> (price: Decimal, label: String)? {
        guard let raw = defaults.string(forKey: regularKey(productId)),
              let label = defaults.string(forKey: regularKey(productId) + ".label") else { return nil }
        let n = NSDecimalNumber(string: raw, locale: Locale(identifier: "en_US_POSIX"))
        guard n != .notANumber else { return nil }
        return (n.decimalValue, label)
    }
}
