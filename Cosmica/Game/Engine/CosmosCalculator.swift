import Foundation

/// True Cosmos (meta-prestige) math. Kept stateless so balance is trivial to tune here.
///
/// Design: once the player has ascended (crossed Absolute at 1e36 ✦), they unlock True
/// Cosmos — a second reset that trades all Cosmic Shards + tree + generators + upgrades
/// for a permanent per-Fragment multiplier. Fragments never reset; each new Cosmos stacks
/// them, so the game keeps a real endless-progression curve past Absolute.
///
/// v4.0 — amounts are `Big` (v3.2 had moved them from Int to Double).
enum CosmosCalculator {
    /// Minimum Cosmic Shard balance before True Cosmos begins yielding fragments.
    /// Below this, the button stays locked so the reset always feels worthwhile.
    static let firstCosmosThreshold: Double = 1_000_000

    /// Scale factor for the sqrt yield curve. Chosen so 1M shards ≈ 50 fragments and
    /// 100M ≈ 500 fragments — a strong reward that grows smoothly without breaking scale.
    private static let scaleFactor: Double = 50.0

    /// Reality Fragments a player would earn if they True Cosmoi'd right now.
    /// Formula: floor(50 · √(shards / 1M)) up to 1B shards, then a gentler
    /// curve (v3.4.1, see `lateExponent`). Requires ≥ 1M shards to yield any.
    static func fragmentsEarned(cosmicShards: Big) -> Big {
        guard cosmicShards >= firstCosmosThreshold else { return .zero }
        return rawFragments(cosmicShards).floored
    }

    // MARK: - v3.4.1 softer curve past a billion shards

    /// Past this many shards the payout grows with `lateExponent` instead of √.
    /// A billion shards is ~1,581 fragments; nothing below it changes.
    static let lateKnee: Double = 1e9
    /// v3.4.1 — the √ curve kept up with shard totals that themselves grow
    /// with every fragment, so each True Cosmos paid ×50 the last and players
    /// reached the 1e300 ceiling in days (planning/endgame_v1.py).
    static let lateExponent: Double = 0.45

    private static var kneeFragments: Double { scaleFactor * (lateKnee / firstCosmosThreshold).squareRoot() }

    /// Unrounded fragments for `shards` (continuous at the knee).
    static func rawFragments(_ shards: Big) -> Big {
        guard shards > 0 else { return .zero }
        if shards <= lateKnee { return (shards / firstCosmosThreshold).squareRoot * scaleFactor }
        return (shards / lateKnee).raised(to: lateExponent) * kneeFragments
    }

    /// Cosmic Shards required to earn at least `target` fragments.
    static func shardsRequired(forFragments target: Big) -> Big {
        guard target > 0 else { return Big(firstCosmosThreshold) }
        if target <= kneeFragments {
            return (target / scaleFactor).raised(to: 2) * firstCosmosThreshold
        }
        return (target / kneeFragments).raised(to: 1 / lateExponent) * lateKnee
    }

    /// Shard threshold at which the *next* fragment would be earned.
    static func nextFragmentThreshold(cosmicShards: Big) -> Big {
        let current = fragmentsEarned(cosmicShards: cosmicShards)
        return shardsRequired(forFragments: current + 1)
    }

    /// Progress in [0, 1] toward the next fragment.
    static func progressToNextFragment(cosmicShards: Big) -> Double {
        let current = fragmentsEarned(cosmicShards: cosmicShards)
        let lower = shardsRequired(forFragments: current)
        let upper = shardsRequired(forFragments: current + 1)
        guard upper > lower else { return 0 }
        let p = ((cosmicShards - lower) / (upper - lower)).double
        return min(max(p, 0), 1)
    }

    /// Permanent multiplier the player is enjoying right now from their accumulated
    /// Reality Fragments. Each fragment contributes +5% additively, so the multiplier
    /// stays readable (100 fragments = ×6, 500 = ×26).
    static func multiplier(fragments: Big) -> Big {
        fragments * 0.05 + 1
    }

    // MARK: - v3.4.1 Cosmos Goal

    /// Orders of magnitude each cosmos adds to its goal.
    static let goalStep: Double = 4

    /// Lifetime Stardust one run in the current cosmos must reach before it can
    /// collapse: 1e40 in cosmos 1, 1e44 in cosmos 2… (cosmos 0 is gated by
    /// Absolute itself, 1e36). v3.4.1 review: "spamming 20 cosmic resets to gain
    /// all 8 pillars". v4.0: no 1e300 cap, and `n` is cosmoi since the last
    /// Omniverse collapse, so the ladder restarts each Omniverse instead of
    /// outrunning dilated production (planning/endgame_v2.py: that race is the wall).
    static func goal(cosmosCount n: Int) -> Big {
        guard n > 0 else { return .zero }
        return Big.fromLog10(36 + goalStep * Double(n))
    }
}
