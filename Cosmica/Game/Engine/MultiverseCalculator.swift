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
///
/// v3.4.1: the fragment bonus now grows with √sparks, so the dip after a big
/// collapse is deeper and takes a few cosmoi to climb out of (the endgame
/// model put the old version's collapses at 100–1,000× each, which is how
/// players reached the 1e300 ceiling in under a week).
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
    static func sparksEarned(realityFragments fragments: Big) -> Big {
        guard fragments >= firstFragments else { return .zero }
        return ((fragments / firstFragments).squareRoot * scale).floored
    }

    /// Reality Fragments needed for at least `target` sparks.
    static func fragmentsRequired(forSparks target: Big) -> Big {
        guard target > 0 else { return Big(firstFragments) }
        return max(Big(firstFragments), (target / scale).raised(to: 2) * firstFragments)
    }

    static func nextSparkThreshold(realityFragments: Big) -> Big {
        fragmentsRequired(forSparks: sparksEarned(realityFragments: realityFragments) + 1)
    }

    /// Progress in [0, 1] toward the next spark (toward the first one below 1,000).
    static func progressToNextSpark(realityFragments f: Big) -> Double {
        let current = sparksEarned(realityFragments: f)
        let lower = current > 0 ? fragmentsRequired(forSparks: current) : Big.zero
        let upper = fragmentsRequired(forSparks: current + 1)
        guard upper > lower else { return 0 }
        return min(max(((f - lower) / (upper - lower)).double, 0), 1)
    }

    /// v4.0 — `Big` (sparks and their multipliers grow without limit).
    static func stardustMultiplier(sparks: Big) -> Big { max(sparks, Big.zero) * stardustPerSpark + 1 }
    /// v3.4.1: grows with √sparks (was linear). Sparks already multiply
    /// Stardust linearly; paying fragments linearly too made every collapse
    /// worth 100–1,000× the one before it, and players hit the 1e300 ceiling
    /// within days (planning/endgame_v1.py). 1 spark is unchanged; 100 sparks
    /// is ×3.5 fragments instead of ×26.
    static func fragmentMultiplier(sparks: Big) -> Big { max(sparks, Big.zero).squareRoot * fragmentBonusPerSpark + 1 }
}
