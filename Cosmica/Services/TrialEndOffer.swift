import Foundation

/// v3.0.5 — when to show the one-time "your automation stopped" offer.
///
/// The Everything Bundle is ~2/3 of all purchases (41 of 60 through Oct 4,
/// 2026) and almost every automation buyer picks it over Automation Core
/// (41 : 2). The moment a 4-hour trial runs out is when a player has just seen
/// what automation does, so that's where the bundle gets offered.
///
/// Rules (all required):
///   - automation isn't owned (bundle or Automation Core)
///   - a trial exists and has ended, within the last 72h (a trial that lapsed
///     days ago isn't "just stopped" any more)
///   - this particular trial hasn't been offered on yet
///   - no offer in the last 24h (repeat ad-watchers aren't nagged daily)
enum TrialEndOffer {
    static let staleAfter: TimeInterval = 72 * 3600
    static let minGap: TimeInterval = 24 * 3600

    static func shouldShow(trialExpiresAt: Date?,
                           automationOwned: Bool,
                           lastOfferedExpiry: Date?,
                           lastShownAt: Date?,
                           now: Date) -> Bool {
        guard !automationOwned, let expiry = trialExpiresAt, expiry <= now else { return false }
        guard now.timeIntervalSince(expiry) <= staleAfter else { return false }
        if let offered = lastOfferedExpiry, abs(offered.timeIntervalSince(expiry)) < 1 { return false }
        if let shown = lastShownAt, now.timeIntervalSince(shown) < minGap { return false }
        return true
    }

    // MARK: - Per-device memory (UserDefaults)

    private static let offeredExpiryKey = "cosmica.trialOffer.offeredExpiry"
    private static let shownAtKey = "cosmica.trialOffer.shownAt"

    static func lastOfferedExpiry(_ d: UserDefaults = .standard) -> Date? {
        d.object(forKey: offeredExpiryKey) as? Date
    }

    static func lastShownAt(_ d: UserDefaults = .standard) -> Date? {
        d.object(forKey: shownAtKey) as? Date
    }

    static func recordShown(forExpiry expiry: Date, at now: Date, _ d: UserDefaults = .standard) {
        d.set(expiry, forKey: offeredExpiryKey)
        d.set(now, forKey: shownAtKey)
    }
}
