import Foundation

/// Big Bang (prestige) math.
///
/// Player can prestige once lifetimeStardust crosses `threshold`.
/// They receive Cosmic Shards equal to `floor(150 * sqrt(lifetime / threshold))`.
/// Each shard grants +2% permanent earnings (compounding via [GameState.shardMultiplier]).
enum PrestigeCalculator {
    static let threshold: Double = 1e12

    /// v2.1.1: shards return as `Double` (was `Int`, which pinned rewards at
    /// Int64.max ≈ 9.22e18 once lifetime crossed ~3.8e33 — well within reach
    /// of Absolute Observers running True Cosmos loops). `state.cosmicShards`
    /// was already Double, so no save migration.
    static func shardsEarned(lifetimeStardust: Double) -> Double {
        guard lifetimeStardust.isFinite, lifetimeStardust >= threshold else { return 0 }
        // Double natively holds up to ~1.7e308; the Int clamp we needed before
        // is gone. Keep the isFinite / >0 guards for defense.
        let raw = 150.0 * sqrt(lifetimeStardust / threshold)
        guard raw.isFinite, raw > 0 else { return 0 }
        return raw.rounded(.down)
    }

    /// Lifetime stardust required to earn at least `targetShards` shards.
    static func lifetimeRequired(forShards targetShards: Double) -> Double {
        guard targetShards > 0 else { return threshold }
        let ratio = pow(targetShards / 150.0, 2.0)
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
