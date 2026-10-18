import Foundation

/// True Cosmos (meta-prestige) math. Kept stateless so balance is trivial to tune here.
///
/// Design: once the player has ascended (crossed Absolute at 1e36 ✦), they unlock True
/// Cosmos — a second reset that trades all Cosmic Shards + tree + generators + upgrades
/// for a permanent per-Fragment multiplier. Fragments never reset; each new Cosmos stacks
/// them, so the game keeps a real endless-progression curve past Absolute.
enum CosmosCalculator {
    /// Minimum Cosmic Shard balance before True Cosmos begins yielding fragments.
    /// Below this, the button stays locked so the reset always feels worthwhile.
    static let firstCosmosThreshold: Double = 1_000_000

    /// Scale factor for the sqrt yield curve. Chosen so 1M shards ≈ 50 fragments and
    /// 100M ≈ 500 fragments — a strong reward that grows smoothly without breaking scale.
    private static let scaleFactor: Double = 50.0

    /// Reality Fragments a player would earn if they True Cosmoi'd right now.
    /// Formula: floor(50 · √(shards / 1M)). Requires ≥ 1M shards to yield any.
    ///
    /// v3.2: `Double` (was `Int`). Converting a Double above Int64.max (~9.2e18)
    /// to Int traps, and that point is ~3.4e40 shards — within reach of the
    /// longest-running saves. Same fix 2.1.1 made for Big Bang shards.
    static func fragmentsEarned(cosmicShards: Double) -> Double {
        guard cosmicShards >= firstCosmosThreshold else { return 0 }
        let raw = (scaleFactor * sqrt(cosmicShards / firstCosmosThreshold)).rounded(.down)
        return raw.isFinite ? raw : 0
    }

    /// Cosmic Shards required to earn at least `target` fragments.
    static func shardsRequired(forFragments target: Double) -> Double {
        guard target > 0 else { return firstCosmosThreshold }
        let ratio = pow(target / scaleFactor, 2.0)
        return firstCosmosThreshold * ratio
    }

    /// Shard threshold at which the *next* fragment would be earned.
    static func nextFragmentThreshold(cosmicShards: Double) -> Double {
        let current = fragmentsEarned(cosmicShards: cosmicShards)
        return shardsRequired(forFragments: current + 1)
    }

    /// Progress in [0, 1] toward the next fragment.
    static func progressToNextFragment(cosmicShards: Double) -> Double {
        let current = fragmentsEarned(cosmicShards: cosmicShards)
        let lower = shardsRequired(forFragments: current)
        let upper = shardsRequired(forFragments: current + 1)
        guard upper > lower else { return 0 }
        let p = (cosmicShards - lower) / (upper - lower)
        return min(max(p, 0), 1)
    }

    /// Permanent multiplier the player is enjoying right now from their accumulated
    /// Reality Fragments. Each fragment contributes +5% additively, so the multiplier
    /// stays readable (100 fragments = ×6, 500 = ×26).
    static func multiplier(fragments: Double) -> Double {
        1.0 + fragments * 0.05
    }
}
