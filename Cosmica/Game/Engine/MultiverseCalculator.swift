import Foundation

/// v3.4 Multiverse Collapse — the third prestige layer, past True Cosmos.
///
/// Trade every Reality Fragment (plus everything a True Cosmos resets) for Void
/// Sparks. Sparks never reset. Each one multiplies Stardust and the Reality
/// Fragments every later True Cosmos pays, so the first True Cosmos after a
/// collapse already puts the player ahead of where they were.
///
/// Why that holds at every size: sparks grow with √fragments, so the earnings
/// a collapse gives up (+5% per fragment) and the head start it buys move
/// together. For F fragments → S = 5·√(F/1000) sparks, recovering the old
/// fragment multiplier takes about (1 + 0.05F)/(1 + 2.5S) fragments, and one
/// minimum True Cosmos pays 50·(1 + 0.25S): 1,000 F → ~56 needed vs ≥112 paid,
/// 10,000 F → ~240 vs ≥237, 1M F → ~2,500 vs ≥2,025 (plus the bigger shard
/// totals a stronger run reaches). So it is never a trap, only a dip.
enum MultiverseCalculator {
    /// True Cosmoi the player must have collapsed before the layer opens.
    static let cosmosRequired = 10
    /// Reality Fragments held before a collapse yields any Void Sparks.
    static let firstFragments: Double = 1_000
    private static let scale: Double = 5

    /// Each unspent Void Spark: +250% Stardust (additive, like fragments).
    static let stardustPerSpark: Double = 2.5
    /// Each unspent Void Spark: +25% Reality Fragments per True Cosmos.
    static let fragmentBonusPerSpark: Double = 0.25

    /// Void Sparks a collapse would pay for `fragments` Reality Fragments:
    /// floor(5 · √(fragments / 1000)), nothing below 1,000.
    static func sparksEarned(realityFragments fragments: Double) -> Double {
        guard fragments >= firstFragments else { return 0 }
        let raw = (scale * sqrt(fragments / firstFragments)).rounded(.down)
        return raw.isFinite ? raw : 0
    }

    /// Reality Fragments needed for at least `target` sparks.
    static func fragmentsRequired(forSparks target: Double) -> Double {
        guard target > 0 else { return firstFragments }
        return max(firstFragments, firstFragments * pow(target / scale, 2))
    }

    static func nextSparkThreshold(realityFragments: Double) -> Double {
        fragmentsRequired(forSparks: sparksEarned(realityFragments: realityFragments) + 1)
    }

    /// Progress in [0, 1] toward the next spark (toward the first one below 1,000).
    static func progressToNextSpark(realityFragments f: Double) -> Double {
        let current = sparksEarned(realityFragments: f)
        let lower = current > 0 ? fragmentsRequired(forSparks: current) : 0
        let upper = fragmentsRequired(forSparks: current + 1)
        guard upper > lower else { return 0 }
        return min(max((f - lower) / (upper - lower), 0), 1)
    }

    static func stardustMultiplier(sparks: Double) -> Double { 1 + stardustPerSpark * max(0, sparks) }
    static func fragmentMultiplier(sparks: Double) -> Double { 1 + fragmentBonusPerSpark * max(0, sparks) }
}
