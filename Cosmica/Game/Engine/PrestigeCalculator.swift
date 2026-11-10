import Foundation

/// Big Bang (prestige) math.
///
/// Player can prestige once lifetimeStardust crosses the unlock floor (see
/// `unlockFloor`). They receive Cosmic Shards equal to
/// `floor(150 * sqrt(lifetime / threshold))`.
/// Each shard grants +2% permanent earnings (compounding via [GameState.shardMultiplier]).
///
/// v4.0 — amounts are `Big` (v2.1.1 had moved them from Int to Double). `Big`
/// has no infinity or NaN, so the old isFinite guards are gone.
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

    static func shardsEarned(lifetimeStardust: Big, floor: Double = threshold) -> Big {
        guard lifetimeStardust >= floor else { return .zero }
        return ((lifetimeStardust / threshold).squareRoot * 150).floored
    }

    // MARK: - v3.3 Kindling

    /// Big Bangs pay this many times the usual shards while Kindling lasts.
    static let kindlingMultiplier: Double = 3
    /// Kindling ends once the player has earned this many lifetime shards: about
    /// what every regular Cosmic Tree level costs (~6,000 ◈). A pacing sim
    /// (planning/pace_v2.py) put an idle player ~7 days from first Big Bang to a
    /// full tree, most of the road to Absolute; Kindling cuts that to ~3.
    static let kindlingCap: Double = 6_000

    static func kindlingActive(lifetimeShards: Big, cosmosCount: Int) -> Bool {
        cosmosCount == 0 && lifetimeShards < kindlingCap
    }

    /// `shards` with Kindling applied. Only the part that fits under the cap is
    /// tripled, so the payout stays continuous: a huge first run can't turn into
    /// a windfall, and crossing the cap never pays less than not crossing it.
    static func kindled(_ shards: Big, lifetimeShards: Big, cosmosCount: Int) -> Big {
        guard shards > 0, kindlingActive(lifetimeShards: lifetimeShards, cosmosCount: cosmosCount) else { return shards }
        let room = Big(kindlingCap) - lifetimeShards
        let tripled = shards * kindlingMultiplier
        if tripled <= room { return tripled }
        return room + (shards - room / kindlingMultiplier)
    }

    /// Lifetime stardust required to earn at least `targetShards` shards.
    static func lifetimeRequired(forShards targetShards: Big) -> Big {
        guard targetShards > 0 else { return Big(threshold) }
        return (targetShards / 150).raised(to: 2) * threshold
    }

    /// Lifetime needed to earn the very next shard above what would currently be awarded.
    ///
    /// v3.0.3: below the unlock floor the answer is the floor itself. The raw
    /// curve says 1 shard at threshold/150² (~44.4M), but nothing pays out
    /// until the floor. Showing 44.4M told players at 5B they were past the
    /// goal (review, 2026-09-26).
    static func nextShardThreshold(lifetimeStardust: Big, floor: Double = threshold) -> Big {
        let current = shardsEarned(lifetimeStardust: lifetimeStardust, floor: floor)
        guard current > 0 else { return Big(floor) }
        return lifetimeRequired(forShards: current + 1)
    }

    /// Progress in [0, 1] toward the next shard (toward unlock, before the first).
    static func progressToNextShard(lifetimeStardust: Big, floor: Double = threshold) -> Double {
        let current = shardsEarned(lifetimeStardust: lifetimeStardust, floor: floor)
        guard current > 0 else {
            guard floor > 0 else { return 0 }
            return min(max((lifetimeStardust / floor).double, 0), 1)
        }
        let lower = lifetimeRequired(forShards: current)
        let upper = lifetimeRequired(forShards: current + 1)
        guard upper > lower else { return 0 }
        let p = ((lifetimeStardust - lower) / (upper - lower)).double
        return min(max(p, 0), 1)
    }
}
