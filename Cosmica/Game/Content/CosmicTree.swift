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
        CosmicSkill(id: "chronal",       name: "Chronal Resonance",    detail: "+12% from Chrono→Primordial gens / lvl", symbol: "clock.arrow.circlepath", baseCost: 5, growth: 1.7, maxLevel: 8),
        CosmicSkill(id: "big_bang",      name: "Big Bang Yield",       detail: "+15% Cosmic Shards on Big Bang / lvl", symbol: "burst.fill",         baseCost: 5, growth: 1.8, maxLevel: 6),
        CosmicSkill(id: "tap_mastery",   name: "Tap Mastery",          detail: "+25% tap value per level",           symbol: "hand.tap.fill",       baseCost: 3, growth: 1.6, maxLevel: 8),
        CosmicSkill(id: "nightwatch",    name: "Nightwatch",           detail: "+2h offline cap per level",          symbol: "moon.zzz.fill",      baseCost: 4, growth: 1.7, maxLevel: 8),
        CosmicSkill(id: "vanguard",      name: "Vanguard",             detail: "Start each Big Bang with more ✦",     symbol: "shippingbox.fill",   baseCost: 5, growth: 1.8, maxLevel: 6),
        CosmicSkill(id: "boost_extend",  name: "Boost Extension",      detail: "+5 min on every 2× boost / lvl",     symbol: "bolt.badge.clock.fill", baseCost: 4, growth: 1.7, maxLevel: 8),

        // v3.0 — Autonomy branch. Each is a one-shot unlock (maxLevel 1) that
        // opens auto-buy on a widening slice of generators. Gated behind
        // Automation Core (checked by AutomationManager.isActive at tick time).
        CosmicSkill(id: "autonomy_reactor",  name: "Autonomous Reactor",  detail: "Unlock auto-buy on Backyard→Orbital generators",  symbol: "gearshape.2.fill",                       baseCost: 25,  growth: 1.0, maxLevel: 1),
        CosmicSkill(id: "autonomy_nexus",    name: "Autonomous Nexus",    detail: "Extend auto-buy through the Wormhole cluster",     symbol: "gearshape.arrow.triangle.2.circlepath",  baseCost: 100, growth: 1.0, maxLevel: 1),
        CosmicSkill(id: "autonomy_absolute", name: "Autonomous Absolute", detail: "Auto-buy on every generator — Multiverse + Chronal", symbol: "infinity",                            baseCost: 500, growth: 1.0, maxLevel: 1),
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

    /// Per-tier generator multiplier: the "Deep Field / Wormhole / Multiverse / Chronal"
    /// clusters. Generator index 0-3 = Deep Field, 4-7 = Wormhole, 8-11 = Multiverse,
    /// 12-15 = Chronal (v1.3).
    static func generatorTierMultiplier(_ generatorIndex: Int, _ l: [String: Int]) -> Double {
        let skillId: String
        switch generatorIndex {
        case 0...3:  skillId = "deep_field"
        case 4...7:  skillId = "wormhole"
        case 8...11: skillId = "multiverse"
        default:     skillId = "chronal"
        }
        return 1 + 0.12 * Double(level(skillId, l))
    }

    /// v3.0 — is auto-buy unlocked for this generator's cluster? Successive Autonomy
    /// nodes cover a widening slice of generators. Independent from the player's
    /// per-generator toggle in `GameState.autoBuyEnabled` — this is the tier gate.
    /// Independent from Automation Core ownership — `AutomationManager.isActive`
    /// handles that gate at tick time.
    static func isGeneratorAutoBuyUnlocked(index: Int, levels: [String: Int]) -> Bool {
        // Cluster boundaries match `generatorTierMultiplier` above.
        // 0-3 (Deep Field) needs Reactor.
        // 4-7 (Wormhole) needs Nexus.
        // 8+  (Multiverse + Chronal) needs Absolute.
        switch index {
        case 0...3:  return level("autonomy_reactor",  levels) >= 1
        case 4...7:  return level("autonomy_nexus",    levels) >= 1
        default:     return level("autonomy_absolute", levels) >= 1
        }
    }
}
