import Foundation

/// Big Bang (prestige) math.
///
/// Player can prestige once lifetimeStardust crosses `threshold`.
/// They receive Cosmic Shards equal to `floor(150 * sqrt(lifetime / threshold))`.
/// Each shard grants +2% permanent earnings (compounding via [GameState.shardMultiplier]).
enum PrestigeCalculator {
    static let threshold: Double = 1e12

    /// Largest `Double` guaranteed to round-trip through `Int` without trapping.
    /// See GameCenterManager for the full explanation of the .nextDown pattern —
    /// `Double(Int.max)` itself rounds up to 2^63, which is one above Int.max.
    private static let safeMaxAsDouble: Double = Double(Int.max).nextDown

    static func shardsEarned(lifetimeStardust: Double) -> Int {
        guard lifetimeStardust.isFinite, lifetimeStardust >= threshold else { return 0 }
        // A True Cosmos endgame player past Absolute Ascension can accumulate
        // lifetime > 1e50; sqrt(1e50/1e12)*150 = 1.5e21, well past Int.max (9.2e18).
        // Clamp to safeMaxAsDouble before the Int() conversion to dodge the trap.
        let raw = 150.0 * sqrt(lifetimeStardust / threshold)
        guard raw.isFinite else { return Int(safeMaxAsDouble) }
        return Int(min(raw, safeMaxAsDouble))
    }

    /// Lifetime stardust required to earn at least `targetShards` shards.
    static func lifetimeRequired(forShards targetShards: Int) -> Double {
        guard targetShards > 0 else { return threshold }
        let ratio = pow(Double(targetShards) / 150.0, 2.0)
        return threshold * ratio
    }

    /// Lifetime needed to earn the very next shard above what would currently be awarded.
    static func nextShardThreshold(lifetimeStardust: Double) -> Double {
        let current = shardsEarned(lifetimeStardust: lifetimeStardust)
        return lifetimeRequired(forShards: current + 1)
    }

    /// Progress in [0, 1] toward the next shard.
    static func progressToNextShard(lifetimeStardust: Double) -> Double {
        let current = shardsEarned(lifetimeStardust: lifetimeStardust)
        let lower = lifetimeRequired(forShards: current)
        let upper = lifetimeRequired(forShards: current + 1)
        guard upper > lower else { return 0 }
        let p = (lifetimeStardust - lower) / (upper - lower)
        return min(max(p, 0), 1)
    }
}
