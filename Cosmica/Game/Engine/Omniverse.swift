import Foundation

/// v4.0 — the Omniverse, the fourth prestige layer, and the dilation that makes it
/// matter. Tuned in planning/omniverse_v1.py (log space, 180 days).
///
/// Why dilation: with the 1e300 ceiling gone, each layer multiplies the one below,
/// so the *exponent* snowballs (endgame_v2.py: an active player at 1e2.6 billion by
/// day 90). Past 1.8e308 every ×10 of production counts at `strength` (0.5 to start),
/// which turns the runaway into a soft wall. Echoes buy the strength back up.
/// Above ~0.65 the runaway returns, so it tops out at 0.62.
enum Dilation {
    /// 1.8e308 — Double's old limit. Dilation starts here and the Omniverse opens here.
    static let threshold = Big(mantissa: 1.8, exponent: 308)
    static let baseStrength: Double = 0.5
    static let maxStrength: Double = 0.62

    /// `x` with every order of magnitude past the threshold counted at `strength`.
    static func apply(_ x: Big, strength: Double) -> Big {
        guard x > threshold else { return x }
        let t = threshold.log10Value
        return Big.fromLog10(t + strength * (x.log10Value - t))
    }
}

enum OmniverseCalculator {
    /// One order of magnitude of Echoes per this many orders of magnitude of best run
    /// past 1.8e308 (1 Echo at the door, 10 at 1e408, 1,000 at 1e608).
    static let echoScale: Double = 100

    /// Echoes an Omniverse collapse pays for the best run since the last one.
    static func echoesEarned(bestRun: Big) -> Big {
        guard bestRun >= Dilation.threshold else { return .zero }
        // +1e-9 in log space so a run exactly on a boundary (10, 100…) isn't floored
        // one short by rounding in the subtraction.
        return Big.fromLog10((bestRun.log10Value - Dilation.threshold.log10Value) / echoScale + 1e-9).floored
    }

    /// Best run needed for at least `target` Echoes.
    static func bestRunRequired(forEchoes target: Big) -> Big {
        guard target > 1 else { return Dilation.threshold }
        return Big.fromLog10(Dilation.threshold.log10Value + echoScale * target.log10Value)
    }

    /// 0…1 toward the next Echo, on a log scale.
    static func progressToNextEcho(bestRun: Big) -> Double {
        let have = echoesEarned(bestRun: bestRun)
        let lower = have > 0 ? bestRunRequired(forEchoes: have) : Big.one
        let upper = bestRunRequired(forEchoes: have + 1)
        let lo = lower.log10Value, hi = upper.log10Value, v = max(bestRun, Big.one).log10Value
        guard hi > lo else { return 0 }
        return min(max((v - lo) / (hi - lo), 0), 1)
    }

    /// Unspent Echoes multiply production ×(1 + Echoes), applied after dilation.
    static func multiplier(echoes: Big) -> Big { max(echoes, Big.zero) + 1 }
}

/// A node in the Omniverse tree, bought with Echoes. Kept, like Wonders, through
/// every reset (an Omniverse collapse included).
struct OmniverseNode: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let baseCost: Double
    let costGrowth: Double
    /// 0 = no limit.
    let maxLevel: Int

    func cost(toReachLevel level: Int) -> Big {
        Big.power(costGrowth, Double(max(0, level - 1))) * baseCost
    }
}

enum OmniverseTree {
    static let veilId = "thin_the_veil"
    static let autoCosmosId = "cosmic_autopilot"
    static let autoCollapseId = "void_autopilot"
    static let sparkMemoryId = "spark_memory"

    /// Dilation strength each Thin the Veil level adds.
    static let veilStep: Double = 0.01
    /// Share of Void Sparks each Spark Memory level keeps through an Omniverse collapse.
    static let sparkMemoryPerLevel: Double = 0.10

    static let all: [OmniverseNode] = [
        OmniverseNode(id: veilId, title: "Thin the Veil",
                      detail: "Past 1.8e308, each ×10 of production counts for 1% more",
                      symbol: "aqi.medium", baseCost: 5, costGrowth: 3, maxLevel: 12),
        OmniverseNode(id: autoCosmosId, title: "Cosmic Autopilot",
                      detail: "True Cosmos runs itself whenever it would at least double your Reality Fragments",
                      symbol: "infinity.circle", baseCost: 3, costGrowth: 1, maxLevel: 1),
        OmniverseNode(id: autoCollapseId, title: "Void Autopilot",
                      detail: "The Multiverse collapses itself whenever it would at least double your Void Sparks",
                      symbol: "circle.hexagongrid", baseCost: 10, costGrowth: 1, maxLevel: 1),
        OmniverseNode(id: sparkMemoryId, title: "Spark Memory",
                      detail: "Keep 10% of your Void Sparks through each Omniverse collapse per level",
                      symbol: "sparkle.magnifyingglass", baseCost: 20, costGrowth: 4, maxLevel: 5),
    ]

    static func node(id: String) -> OmniverseNode? { all.first { $0.id == id } }
}
