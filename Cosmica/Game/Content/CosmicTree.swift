import Foundation

/// One permanent, level-able node in the Cosmic tree. Levels are bought with Cosmic
/// Shards and persist across Big Bangs.
struct CosmicSkill: Identifiable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
    let baseCost: Int
    let growth: Double
    let maxLevel: Int

    /// Cosmic Shard cost to buy the level *above* `level`.
    func cost(atLevel level: Int) -> Int {
        Int((Double(baseCost) * pow(growth, Double(level))).rounded())
    }
}

/// The Cosmic tree — Cosmica's permanent meta-progression. Cosmic Shards double as
/// a spendable currency (nodes here consume them) and a passive multiplier
/// (each un-spent shard gives +2% earnings). That creates a real invest-or-hoard
/// decision every Big Bang.
enum CosmicTree {
    static let skills: [CosmicSkill] = [
        CosmicSkill(id: "focus",         name: "Cosmic Focus",         detail: "+8% ✦/sec per level",                symbol: "sparkles",           baseCost: 3, growth: 1.6, maxLevel: 12),
        CosmicSkill(id: "harvest",       name: "Harvest Moon",         detail: "+10% Stardust from all sources / lvl", symbol: "moon.stars",         baseCost: 2, growth: 1.6, maxLevel: 12),
        CosmicSkill(id: "deep_field",    name: "Deep Field",           detail: "+12% from Backyard→Orbital gens / lvl", symbol: "scope",              baseCost: 4, growth: 1.7, maxLevel: 8),
        CosmicSkill(id: "wormhole",      name: "Wormhole Resonance",   detail: "+12% from Solar→Wormhole gens / lvl",  symbol: "tornado",            baseCost: 4, growth: 1.7, maxLevel: 8),
        CosmicSkill(id: "multiverse",    name: "Multiverse Weave",     detail: "+12% from Dyson→Demiurge gens / lvl", symbol: "circle.dotted.and.circle", baseCost: 4, growth: 1.7, maxLevel: 8),
        CosmicSkill(id: "big_bang",      name: "Big Bang Yield",       detail: "+15% Cosmic Shards on Big Bang / lvl", symbol: "burst.fill",         baseCost: 5, growth: 1.8, maxLevel: 6),
        CosmicSkill(id: "tap_mastery",   name: "Tap Mastery",          detail: "+25% tap value per level",           symbol: "hand.tap.fill",       baseCost: 3, growth: 1.6, maxLevel: 8),
        CosmicSkill(id: "nightwatch",    name: "Nightwatch",           detail: "+2h offline cap per level",          symbol: "moon.zzz.fill",      baseCost: 4, growth: 1.7, maxLevel: 8),
        CosmicSkill(id: "vanguard",      name: "Vanguard",             detail: "Start each Big Bang with more ✦",     symbol: "shippingbox.fill",   baseCost: 5, growth: 1.8, maxLevel: 6),
        CosmicSkill(id: "boost_extend",  name: "Boost Extension",      detail: "+5 min on every 2× boost / lvl",     symbol: "bolt.badge.clock.fill", baseCost: 4, growth: 1.7, maxLevel: 8),
    ]

    static func skill(_ id: String) -> CosmicSkill? { skills.first { $0.id == id } }
    static func level(_ id: String, _ l: [String: Int]) -> Int { l[id] ?? 0 }

    // MARK: - Effect accessors

    static func focusMultiplier(_ l: [String: Int]) -> Double { 1 + 0.08 * Double(level("focus", l)) }
    static func harvestMultiplier(_ l: [String: Int]) -> Double { 1 + 0.10 * Double(level("harvest", l)) }
    static func bigBangYieldMultiplier(_ l: [String: Int]) -> Double { 1 + 0.15 * Double(level("big_bang", l)) }
    static func tapMultiplier(_ l: [String: Int]) -> Double { 1 + 0.25 * Double(level("tap_mastery", l)) }
    static func boostExtensionSeconds(_ l: [String: Int]) -> TimeInterval { 300 * Double(level("boost_extend", l)) }
    static func offlineCapBonus(_ l: [String: Int]) -> TimeInterval { 2 * 3600 * Double(level("nightwatch", l)) }

    static func startingStardust(_ l: [String: Int]) -> Double {
        let lvl = level("vanguard", l)
        guard lvl > 0 else { return 0 }
        return 100 * pow(10, Double(lvl))   // 1K, 10K, 100K…
    }

    /// Per-tier generator multiplier: the "Deep Field / Wormhole / Multiverse" clusters.
    /// Generator index 0-3 = Deep Field, 4-7 = Wormhole, 8-11 = Multiverse.
    static func generatorTierMultiplier(_ generatorIndex: Int, _ l: [String: Int]) -> Double {
        let skillId: String
        switch generatorIndex {
        case 0...3: skillId = "deep_field"
        case 4...7: skillId = "wormhole"
        default:    skillId = "multiverse"
        }
        return 1 + 0.12 * Double(level(skillId, l))
    }
}
