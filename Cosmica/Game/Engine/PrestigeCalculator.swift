import Foundation

/// Big Bang (prestige) math.
///
/// Player can prestige once lifetimeStardust crosses `threshold`.
/// They receive Cosmic Shards equal to `floor(150 * sqrt(lifetime / threshold))`.
/// Each shard grants +2% permanent earnings (compounding via [GameState.shardMultiplier]).
enum PrestigeCalculator {
    static let threshold: Double = 1e12

    static func shardsEarned(lifetimeStardust: Double) -> Int {
        guard lifetimeStardust >= threshold else { return 0 }
        return Int(150.0 * sqrt(lifetimeStardust / threshold))
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
