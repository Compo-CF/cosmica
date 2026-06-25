import Foundation

/// Computes catch-up earnings on launch / foregrounding, based on `lastSeen` timestamp.
/// Offline earnings are capped (8h default; 24h with rewarded ad) and earn at 50% of
/// the online rate to keep online play meaningful.
enum OfflineAccrual {
    static let baseCap: TimeInterval = 8 * 3600          // 8 hours
    static let extendedCap: TimeInterval = 24 * 3600     // 24 hours with rewarded ad
    static let offlineRate: Double = 0.5                 // 50% of online rate

    struct Result: Equatable {
        let stardustEarned: Double
        let secondsElapsed: TimeInterval
        let secondsCounted: TimeInterval
        let capUsed: TimeInterval
        let wasCapped: Bool
    }

    static func compute(now: Date,
                        lastSeen: Date,
                        ratePerSecond: Double,
                        extended: Bool = false) -> Result {
        let elapsed = max(0, now.timeIntervalSince(lastSeen))
        let cap = extended ? extendedCap : baseCap
        let counted = min(elapsed, cap)
        let earned = max(0, ratePerSecond) * counted * offlineRate
        return Result(
            stardustEarned: earned,
            secondsElapsed: elapsed,
            secondsCounted: counted,
            capUsed: cap,
            wasCapped: elapsed > cap
        )
    }
}
