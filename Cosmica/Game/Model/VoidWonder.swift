import Foundation

/// v3.4 — Wonders bought with Void Sparks, the Multiverse Collapse currency.
/// Like Cosmic Wonders they survive every reset. Levels live in
/// `GameState.wonderLevels` under their `void_` ids; they are deliberately kept
/// out of `builtWonderIds`, which counts the shard Wonders (and their
/// achievements).
///
/// Spending sparks lowers the passive bonus unspent sparks give, the same
/// invest-or-hoard choice shards have always been.
struct VoidWonder: Identifiable, Hashable {
    let id: String
    let title: String
    let flavor: String
    let symbol: String
    let colorHex: String
    let multiverseRequired: Int
    /// Spark cost of level 1; each later level costs `costGrowth` × the last.
    let sparkCost: Double
    let costGrowth: Double
    /// 0 = no limit.
    let maxLevel: Int

    func cost(toReachLevel level: Int) -> Double {
        sparkCost * pow(costGrowth, Double(max(0, level - 1)))
    }

    func effect(atLevel level: Int) -> String {
        let l = max(1, level)
        switch id {
        case VoidWonderCatalog.seedId:
            return "Keep \(Int(VoidWonderCatalog.carryPerLevel * 100 * Double(min(l, maxLevel))))% of your Cosmic Shards through every True Cosmos"
        case VoidWonderCatalog.furnaceId:
            return "Big Bangs pay ×\(Formatter.count(pow(2, Double(l)))) Cosmic Shards"
        case VoidWonderCatalog.prismId:
            return "True Cosmos pays ×\(Formatter.count(pow(2, Double(l)))) Reality Fragments"
        default:
            return ""
        }
    }
}

enum VoidWonderCatalog {
    static let seedId = "void_seed"
    static let furnaceId = "void_furnace"
    static let prismId = "void_prism"

    /// Null Seed: share of Cosmic Shards kept through True Cosmos, per level.
    static let carryPerLevel = 0.10

    static let all: [VoidWonder] = [
        VoidWonder(id: seedId, title: "Null Seed",
                   flavor: "A grain of nothing that remembers what the last universe held.",
                   symbol: "leaf.circle.fill", colorHex: "8C7CFF",
                   multiverseRequired: 1, sparkCost: 2, costGrowth: 2, maxLevel: 5),
        VoidWonder(id: furnaceId, title: "Spark Furnace",
                   flavor: "It burns the space between universes and leaves shards in the ash.",
                   symbol: "flame.circle.fill", colorHex: "FF7A45",
                   multiverseRequired: 1, sparkCost: 3, costGrowth: 3, maxLevel: 0),
        VoidWonder(id: prismId, title: "Fragment Prism",
                   flavor: "Split one collapsing cosmos and it falls into many.",
                   symbol: "rhombus.fill", colorHex: "5CE1E6",
                   multiverseRequired: 2, sparkCost: 5, costGrowth: 4, maxLevel: 0),
    ]

    static func wonder(id: String) -> VoidWonder? { all.first { $0.id == id } }
}
