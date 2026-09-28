import Foundation

/// Big Bang (prestige) math.
///
/// Player can prestige once lifetimeStardust crosses the unlock floor (see
/// `unlockFloor`). They receive Cosmic Shards equal to
/// `floor(150 * sqrt(lifetime / threshold))`.
/// Each shard grants +2% permanent earnings (compounding via [GameState.shardMultiplier]).
enum PrestigeCalculator {
    /// Scale of the shard curve (150 shards at exactly this lifetime) and the
    /// standard unlock floor once a player is past the first-cosmos ramp.
    static let threshold: Double = 1e12

    /// v3.0.4 — lifetime stardust needed to Big Bang right now.
    ///
    /// In the first cosmos the first two Big Bangs unlock early: 10B, then 100B,
    /// then 1T as before. A pacing sim put a fresh player ~66h of active play
    /// from the old 1T floor, which lined up with D7 retention of ~4% and a
    /// review from a player stuck at 5B. The payout stays on the same curve, so
    /// an early Big Bang pays less (15 ◈ at 10B, 47 ◈ at 100B) and waiting still
    /// pays more. After a True Cosmos the player has fragment multipliers, so the
    /// ramp doesn't reapply.
    static func unlockFloor(prestigeCount: Int, cosmosCount: Int) -> Double {
        guard cosmosCount == 0 else { return threshold }
        switch prestigeCount {
        case 0:  return 1e10
        case 1:  return 1e11
        default: return threshold
        }
    }

    /// v2.1.1: shards return as `Double` (was `Int`, which pinned rewards at
    /// Int64.max ≈ 9.22e18 once lifetime crossed ~3.8e33 — well within reach
    /// of Absolute Observers running True Cosmos loops). `state.cosmicShards`
    /// was already Double, so no save migration.
    static func shardsEarned(lifetimeStardust: Double, floor: Double = threshold) -> Double {
        guard lifetimeStardust.isFinite, lifetimeStardust >= floor else { return 0 }
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
    ///
    /// v3.0.3: below the unlock floor the answer is the floor itself. The raw
    /// curve says 1 shard at threshold/150² (~44.4M), but nothing pays out
    /// until the floor. Showing 44.4M told players at 5B they were past the
    /// goal (review, 2026-09-26).
    static func nextShardThreshold(lifetimeStardust: Double, floor: Double = threshold) -> Double {
        let current = shardsEarned(lifetimeStardust: lifetimeStardust, floor: floor)
        guard current > 0 else { return floor }
        return lifetimeRequired(forShards: current + 1)
    }

    /// Progress in [0, 1] toward the next shard (toward unlock, before the first).
    static func progressToNextShard(lifetimeStardust: Double, floor: Double = threshold) -> Double {
        let current = shardsEarned(lifetimeStardust: lifetimeStardust, floor: floor)
        guard current > 0 else {
            guard lifetimeStardust.isFinite, floor > 0 else { return 0 }
            return min(max(lifetimeStardust / floor, 0), 1)
        }
        let lower = lifetimeRequired(forShards: current)
        let upper = lifetimeRequired(forShards: current + 1)
        guard upper > lower else { return 0 }
        let p = (lifetimeStardust - lower) / (upper - lower)
        return min(max(p, 0), 1)
    }
}
