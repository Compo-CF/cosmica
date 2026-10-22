import Foundation

/// One permanent, level-able node in the Cosmic tree. Levels are bought with Cosmic
/// Shards and persist across Big Bangs.
///
/// v3.3 — Stellar ranks. The whole tree used to cost ~5,000 shards, so late players
/// maxed it in a run or two and had nothing left to buy (App Store review, Oct 2026).
/// Production nodes now keep going past `maxLevel`: each rank multiplies the node's
/// effect by `rankMultiplier` and costs 4× the one before. Because every unspent
/// shard is also +2% earnings, a rank is only worth buying while it costs a modest
/// share of the player's shards — so ranks pace themselves to any wealth.
struct CosmicSkill: Identifiable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
    let baseCost: Int
    let growth: Double
    let maxLevel: Int
    /// Effect multiplier per Stellar rank past `maxLevel`; nil = no ranks.
    var rankMultiplier: Double? = nil

    /// Each Stellar rank costs this many times the previous one.
    static let rankCostGrowth: Double = 4

    var hasRanks: Bool { rankMultiplier != nil }

    /// Cosmic Shard cost to buy the level *above* `level`. Double (was Int): rank
    /// costs grow without limit and an Int conversion would trap past ~9.2e18.
    func cost(atLevel level: Int) -> Double {
        if level < maxLevel {
            return (Double(baseCost) * pow(growth, Double(level))).rounded()
        }
        let lastRegular = Double(baseCost) * pow(growth, Double(maxLevel - 1))
        return (lastRegular * pow(Self.rankCostGrowth, Double(level - maxLevel + 1))).rounded()
    }

    /// Whether another level (regular or Stellar rank) can be bought.
    func canLevel(from level: Int) -> Bool { level < maxLevel || hasRanks }
}

/// The Cosmic tree — Cosmica's permanent meta-progression. Cosmic Shards double as
/// a spendable currency (nodes here consume them) and a passive multiplier
/// (each un-spent shard gives +2% earnings). That creates a real invest-or-hoard
/// decision every Big Bang.
enum CosmicTree {
    static let skills: [CosmicSkill] = [
        CosmicSkill(id: "focus",         name: "Cosmic Focus",         detail: "+8% ✦/sec per level",                symbol: "sparkles",           baseCost: 3, growth: 1.6, maxLevel: 12, rankMultiplier: 1.10),
        CosmicSkill(id: "harvest",       name: "Harvest Moon",         detail: "+10% Stardust from all sources / lvl", symbol: "moon.stars",         baseCost: 2, growth: 1.6, maxLevel: 12, rankMultiplier: 1.10),
        CosmicSkill(id: "deep_field",    name: "Deep Field",           detail: "+12% from Backyard→Orbital gens / lvl", symbol: "scope",              baseCost: 4, growth: 1.7, maxLevel: 8, rankMultiplier: 1.15),
        CosmicSkill(id: "wormhole",      name: "Wormhole Resonance",   detail: "+12% from Solar→Wormhole gens / lvl",  symbol: "tornado",            baseCost: 4, growth: 1.7, maxLevel: 8, rankMultiplier: 1.15),
        CosmicSkill(id: "multiverse",    name: "Multiverse Weave",     detail: "+12% from Dyson→Demiurge gens / lvl", symbol: "circle.dotted.and.circle", baseCost: 4, growth: 1.7, maxLevel: 8, rankMultiplier: 1.15),
        CosmicSkill(id: "chronal",       name: "Chronal Resonance",    detail: "+12% from Chrono→Primordial gens / lvl", symbol: "clock.arrow.circlepath", baseCost: 5, growth: 1.7, maxLevel: 8, rankMultiplier: 1.15),
        CosmicSkill(id: "big_bang",      name: "Big Bang Yield",       detail: "+15% Cosmic Shards on Big Bang / lvl", symbol: "burst.fill",         baseCost: 5, growth: 1.8, maxLevel: 6, rankMultiplier: 1.10),
        CosmicSkill(id: "tap_mastery",   name: "Tap Mastery",          detail: "+25% tap value per level",           symbol: "hand.tap.fill",       baseCost: 3, growth: 1.6, maxLevel: 8, rankMultiplier: 1.25),
        CosmicSkill(id: "nightwatch",    name: "Nightwatch",           detail: "+2h offline cap per level",          symbol: "moon.zzz.fill",      baseCost: 4, growth: 1.7, maxLevel: 8),
        CosmicSkill(id: "vanguard",      name: "Vanguard",             detail: "Start each Big Bang with more ✦",     symbol: "shippingbox.fill",   baseCost: 5, growth: 1.8, maxLevel: 6),
        CosmicSkill(id: "boost_extend",  name: "Boost Extension",      detail: "+5 min on every 2× boost / lvl",     symbol: "bolt.badge.clock.fill", baseCost: 4, growth: 1.7, maxLevel: 8),

        // v3.0 — Autonomy branch. Each is a one-shot unlock (maxLevel 1) that
        // opens auto-buy on a widening slice of generators. Gated behind
        // Automation Core (checked by AutomationManager.isActive at tick time).
        //
        // v3.0.4 — the first cluster (Backyard→Orbital) no longer needs a node:
        // the old 25-shard "Autonomous Reactor" could only be bought after a Big
        // Bang, so a day-one trial or purchase did nothing for days. Automation
        // now covers that cluster on its own; `GameState` refunds anyone who
        // bought Reactor (see `reactorSkillId`).
        CosmicSkill(id: "autonomy_nexus",    name: "Autonomous Nexus",    detail: "Extend auto-buy through the Wormhole cluster",     symbol: "gearshape.arrow.triangle.2.circlepath",  baseCost: 100, growth: 1.0, maxLevel: 1),
        CosmicSkill(id: "autonomy_absolute", name: "Autonomous Absolute", detail: "Auto-buy on every generator — Multiverse + Chronal", symbol: "infinity",                            baseCost: 500, growth: 1.0, maxLevel: 1),
    ]

    static func skill(_ id: String) -> CosmicSkill? { skills.first { $0.id == id } }
    static func level(_ id: String, _ l: [String: Int]) -> Int { l[id] ?? 0 }

    /// Regular levels (capped at maxLevel) and Stellar ranks above them.
    static func split(_ id: String, _ l: [String: Int]) -> (regular: Int, ranks: Int) {
        let lvl = level(id, l)
        guard let cap = skill(id)?.maxLevel else { return (lvl, 0) }
        return (min(lvl, cap), max(0, lvl - cap))
    }

    /// Effect of a node: `perLevel` per regular level, then × its rank multiplier per rank.
    static func effect(_ id: String, _ l: [String: Int], perLevel: Double) -> Double {
        let (regular, ranks) = split(id, l)
        let rank = skill(id)?.rankMultiplier ?? 1
        return (1 + perLevel * Double(regular)) * pow(rank, Double(ranks))
    }

    // MARK: - Effect accessors

    static func focusMultiplier(_ l: [String: Int]) -> Double { effect("focus", l, perLevel: 0.08) }
    static func harvestMultiplier(_ l: [String: Int]) -> Double { effect("harvest", l, perLevel: 0.10) }
    static func bigBangYieldMultiplier(_ l: [String: Int]) -> Double { effect("big_bang", l, perLevel: 0.15) }
    static func tapMultiplier(_ l: [String: Int]) -> Double { effect("tap_mastery", l, perLevel: 0.25) }
    static func boostExtensionSeconds(_ l: [String: Int]) -> TimeInterval { 300 * Double(split("boost_extend", l).regular) }
    static func offlineCapBonus(_ l: [String: Int]) -> TimeInterval { 2 * 3600 * Double(split("nightwatch", l).regular) }

    static func startingStardust(_ l: [String: Int]) -> Double {
        let lvl = split("vanguard", l).regular
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
        return effect(skillId, l, perLevel: 0.12)
    }

    /// v3.0 — is auto-buy unlocked for this generator's cluster? Successive Autonomy
    /// nodes cover a widening slice of generators. Independent from the player's
    /// per-generator toggle in `GameState.autoBuyEnabled` — this is the tier gate.
    /// Independent from Automation Core ownership — `AutomationManager.isActive`
    /// handles that gate at tick time.
    static func isGeneratorAutoBuyUnlocked(index: Int, levels: [String: Int]) -> Bool {
        // Cluster boundaries match `generatorTierMultiplier` above.
        // 0-3 (Deep Field) comes with automation itself (v3.0.4).
        // 4-7 (Wormhole) needs Nexus.
        // 8+  (Multiverse + Chronal) needs Absolute.
        switch index {
        case 0...3:  return true
        case 4...7:  return level("autonomy_nexus",    levels) >= 1
        default:     return level("autonomy_absolute", levels) >= 1
        }
    }

    /// v3.0.4 — retired node. Kept only so saves that bought it can be refunded.
    static let reactorSkillId = "autonomy_reactor"
    static let reactorRefund: Double = 25
}
